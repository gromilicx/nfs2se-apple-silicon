#include <lib/gamepad.h>
#include <algorithm>
#include <cmath>
#include <cstring>
#include <limits>

namespace win32
{

namespace
{
constexpr size_t mouseBufferCapacity = 1024;

x86::sreg32 takeWholeDelta(double& fraction, double delta)
{
    fraction += delta;
    const double whole = std::trunc(fraction);
    const auto result = static_cast<x86::sreg32>(std::clamp(whole,
        double(std::numeric_limits<x86::sreg32>::min()),
        double(std::numeric_limits<x86::sreg32>::max())));
    fraction -= whole;
    return result;
}

x86::sreg32 clampDelta(x86::sreg64 delta)
{
    return static_cast<x86::sreg32>(std::clamp(delta,
        x86::sreg64(std::numeric_limits<x86::sreg32>::min()),
        x86::sreg64(std::numeric_limits<x86::sreg32>::max())));
}

int buttonIndex(Uint8 button)
{
    switch (button)
    {
    case SDL_BUTTON_LEFT: return 0;
    case SDL_BUTTON_RIGHT: return 1;
    case SDL_BUTTON_MIDDLE: return 2;
    case SDL_BUTTON_X1: return 3;
    case SDL_BUTTON_X2: return 4;
    default: return button >= 6 && button <= 8 ? button - 1 : -1;
    }
}
}

Mouse::Mouse()
    : m_mutex(SDL_CreateMutex())
{
    NFS2_ASSERT(m_mutex);
    NFS2_ASSERT(SDL_AddEventWatch(&watchEvent, this));
    SDL_LogDebug(SDL_LOG_CATEGORY_INPUT, "DirectInput mouse created; SDL event watch active");
}

Mouse::~Mouse()
{
    SDL_RemoveEventWatch(&watchEvent, this);
    SDL_DestroyMutex(m_mutex);
}

x86::reg32 Mouse::getButtonCount() const { return 8; }
x86::reg32 Mouse::getAxesCount() const { return 3; }

void Mouse::updateScale(SDL_WindowID windowID)
{
    // Native event watches normally run while the main thread pumps events.
    // SDL_PushEvent can also invoke them from workers, where video queries
    // are forbidden; keep the last main-thread scale in that case.
    if (!SDL_IsMainThread())
        return;
    SDL_Window* window = SDL_GetWindowFromID(windowID);
    int width = 0, height = 0;
    if (window && SDL_GetWindowSize(window, &width, &height) && width > 0 && height > 0)
    {
        const double viewportWidth = std::min(double(width), double(height) * 4.0 / 3.0);
        const double viewportHeight = std::min(double(height), double(width) * 3.0 / 4.0);
        m_scaleX = static_cast<float>(640.0 / viewportWidth);
        m_scaleY = static_cast<float>(480.0 / viewportHeight);
    }
}

void Mouse::appendEvent(x86::reg32 offset, x86::sreg32 data, Uint64 timestamp)
{
    if (m_events.size() == mouseBufferCapacity)
    {
        m_events.pop_front();
        m_overflow = true;
    }
    m_events.push_back({offset, static_cast<x86::reg32>(data),
        static_cast<x86::reg32>(timestamp / SDL_NS_PER_MS), ++m_sequence, 0});
    SDL_LogDebug(SDL_LOG_CATEGORY_INPUT, "Mouse event #%u: offset=%u data=%d queued=%zu",
                 m_sequence, offset, data, m_events.size());
}

bool SDLCALL Mouse::watchEvent(void* userdata, SDL_Event* event)
{
    auto* mouse = static_cast<Mouse*>(userdata);
    if (event->type != SDL_EVENT_MOUSE_MOTION &&
        event->type != SDL_EVENT_MOUSE_BUTTON_DOWN &&
        event->type != SDL_EVENT_MOUSE_BUTTON_UP &&
        event->type != SDL_EVENT_MOUSE_WHEEL &&
        event->type != SDL_EVENT_WINDOW_FOCUS_LOST)
        return true;

    SDL_LockMutex(mouse->m_mutex);
    switch (event->type)
    {
    case SDL_EVENT_MOUSE_MOTION:
    {
        mouse->updateScale(event->motion.windowID);
        const auto dx = takeWholeDelta(mouse->m_fractionX, event->motion.xrel * mouse->m_scaleX);
        const auto dy = takeWholeDelta(mouse->m_fractionY, event->motion.yrel * mouse->m_scaleY);
        mouse->m_deltaX += dx;
        mouse->m_deltaY += dy;
        if (dx) mouse->appendEvent(0, dx, event->motion.timestamp);
        if (dy) mouse->appendEvent(4, dy, event->motion.timestamp);
        break;
    }
    case SDL_EVENT_MOUSE_BUTTON_DOWN:
    case SDL_EVENT_MOUSE_BUTTON_UP:
    {
        const int index = buttonIndex(event->button.button);
        if (index >= 0)
        {
            const x86::reg8 value = event->button.down ? 0x80 : 0;
            if (mouse->m_buttons[index] != value)
            {
                mouse->m_buttons[index] = value;
                mouse->appendEvent(12 + index, value, event->button.timestamp);
            }
        }
        break;
    }
    case SDL_EVENT_MOUSE_WHEEL:
    {
        const double direction = event->wheel.direction == SDL_MOUSEWHEEL_FLIPPED ? -1.0 : 1.0;
        const auto dz = takeWholeDelta(mouse->m_fractionZ, event->wheel.y * direction * 120.0);
        mouse->m_deltaZ += dz;
        if (dz) mouse->appendEvent(8, dz, event->wheel.timestamp);
        break;
    }
    case SDL_EVENT_WINDOW_FOCUS_LOST:
        for (int index = 0; index < 8; ++index)
        {
            if (mouse->m_buttons[index])
            {
                mouse->m_buttons[index] = 0;
                mouse->appendEvent(12 + index, 0, event->window.timestamp);
            }
        }
        break;
    default: break;
    }
    SDL_UnlockMutex(mouse->m_mutex);
    return true;
}

Mouse::State Mouse::getState()
{
    SDL_LockMutex(m_mutex);
    State result{clampDelta(m_deltaX), clampDelta(m_deltaY), clampDelta(m_deltaZ), {}};
    std::memcpy(result.buttons, m_buttons, sizeof(m_buttons));
    m_deltaX = m_deltaY = m_deltaZ = 0;
    SDL_UnlockMutex(m_mutex);
    return result;
}

x86::reg32 Mouse::getBufferedData(x86::reg32 objectSize, void* data,
                                  x86::reg32& count, bool peek)
{
    // DirectInput 3 uses 16-byte records; later 32-bit versions append uAppData.
    if (objectSize != 16 && objectSize != sizeof(BufferedEvent))
        return 0x80070057; // E_INVALIDARG
    SDL_LockMutex(m_mutex);
    const x86::reg32 requested = count;
    const size_t available = std::min(size_t(count), m_events.size());
    ++m_readCount;
    if (available || m_overflow || m_readCount <= 4)
        SDL_LogDebug(SDL_LOG_CATEGORY_INPUT,
                     "Mouse GetDeviceData #%u: size=%u requested=%u returned=%zu peek=%d overflow=%d",
                     m_readCount, objectSize, requested, available, int(peek), int(m_overflow));
    auto* destination = static_cast<unsigned char*>(data);
    for (size_t index = 0; destination && index < available; ++index)
        std::memcpy(destination + index * objectSize, &m_events[index], objectSize);
    count = static_cast<x86::reg32>(available);
    const x86::reg32 result = m_overflow ? 1 : 0; // DI_BUFFEROVERFLOW / DI_OK
    if (!peek)
    {
        m_events.erase(m_events.begin(), m_events.begin() + available);
        m_overflow = false;
    }
    SDL_UnlockMutex(m_mutex);
    return result;
}

}

#include "cheats.h"
#include <cpu.h>
#include <lib/winapp.h>
#include <algorithm>
#include <array>
#include <chrono>
#include <mutex>
#include <utility>

namespace nfs2se::cheats {
namespace {
using Clock = std::chrono::steady_clock;
std::mutex mutex;
Snapshot cached;
Clock::time_point deadline{};
std::string command;
bool executing = false;
bool night = false;
bool cameras = false;
thread_local bool processing = false;
thread_local unsigned movieDepth = 0;
constexpr std::array<x86::reg32, 6> flags = {
    0x4d24f8, 0x4d2500, 0x4d2504, 0x4d250c, 0x4d2510, 0x4d2514
};
constexpr std::array<const char*, 6> flagCodes = {
    "chase", "pioneer", "rushhour", "rain", "roadrage", "slip"
};
const std::array<std::string, 15> typed = {
    "fzr2000", "tombstone", "bomber", "hollywood", "pioneer", "slip", "slot",
    "rain", "chase", "rushhour", "rexhour", "madland", "schoolzone", "vip", "roadrage"
};
bool allowed(const std::string& code) {
    if (std::find(typed.begin(), typed.end(), code) != typed.end()) return true;
    if (code == "night" || code == "cameras" || code == "normalcar" || code == "reset") return true;
    return code.size() == 4 && code[0] == 'g' && code[1] == 'o' &&
        code[2] >= '1' && code[2] <= '5' && code[3] >= '0' && code[3] <= '9' &&
        ((code[2] - '0') * 10 + code[3] - '0') >= 18 &&
        ((code[2] - '0') * 10 + code[3] - '0') <= 51;
}
bool menuReady(win32::WinApplication* app) {
    // These two canvases exist only between original frontend setup/cleanup.
    // Movie input also calls frontendTick, so an input tick alone is insufficient.
    return movieDepth == 0 && app->getMemory<x86::reg32>(0x4d58b8) != 0 &&
        app->getMemory<x86::reg32>(0x4d58bc) != 0;
}
bool singleRace(win32::WinApplication* app) {
    return app->getMemory<x86::reg8>(0x4dde89) <= 1 &&
        app->getMemory<x86::reg8>(0x4dde8a) == 0;
}
void normalCar(win32::WinApplication* app) {
    app->getMemory<x86::reg8>(0x4bfcdc) = 0;
    app->getMemory<x86::reg8>(0x4bfcdd) = 0;
}
Snapshot readState(win32::WinApplication* app) {
    Snapshot state;
    state.menuReady = menuReady(app);
    state.singleRace = singleRace(app);
    for (size_t i = 0; i < flags.size(); ++i)
        if (app->getMemory<x86::reg32>(flags[i])) state.activeCodes.emplace_back(flagCodes[i]);
    if (app->getMemory<x86::reg8>(0x4dde9e)) state.activeCodes.emplace_back("slot");
    if (app->getMemory<x86::reg8>(0x4dde9c) & 1) state.activeCodes.emplace_back("hollywood");
    const unsigned unlocked = app->getMemory<x86::reg8>(0x4dde9d);
    if (unlocked >= 1) state.activeCodes.emplace_back("bomber");
    if (unlocked >= 2) state.activeCodes.emplace_back("tombstone");
    if (unlocked >= 3) state.activeCodes.emplace_back("fzr2000");
    const unsigned model = app->getMemory<x86::reg8>(0x4bfcdc);
    if (model >= 18 && model <= 51) {
        for (unsigned id = 18; id <= 51; ++id) {
            const bool bus = id == 18 || id == 22 || id == 24 || id == 25 || id == 29 || id == 30 || id == 32;
            if (model == (bus ? 20 : id)) state.activeCodes.push_back("go" + std::to_string(id));
        }
        if (app->getMemory<x86::reg32>(0x4d2504)) {
            if (model == 43) state.activeCodes.emplace_back("rexhour");
            if (model == 42) state.activeCodes.emplace_back("madland");
            if (model == 20) state.activeCodes.emplace_back("schoolzone");
            if (model == 35) state.activeCodes.emplace_back("vip");
        }
    }
    return state;
}
void expire() {
    if (!command.empty() && Clock::now() > deadline) {
        command.clear();
        cached.feedback = "Kod nije primenjen. Vrati se u meni igre pa pokušaj ponovo.";
    }
}
struct SavedKeys { bool applied; std::array<x86::reg8, 3> values; };
thread_local std::vector<SavedKeys> cameraKeys, nightKeys;
}

Snapshot snapshot() {
    std::lock_guard<std::mutex> lock(mutex);
    expire();
    Snapshot result = cached;
    result.pending = executing || !command.empty();
    if (night) result.activeCodes.emplace_back("night");
    if (cameras) result.activeCodes.emplace_back("cameras");
    return result;
}

bool queue(const std::string& code) {
    std::lock_guard<std::mutex> lock(mutex);
    expire();
    if (!allowed(code) || executing || !command.empty() || !cached.menuReady || !cached.singleRace) return false;
    command = code;
    deadline = Clock::now() + std::chrono::seconds(2);
    cached.feedback = "Primenjujem kod…";
    return true;
}

void frontendClosed() {
    // Opening a native panel pauses the original frontend on focus loss. Keep
    // its last synchronized state while browsing, and invalidate at the actual
    // frontend teardown rather than on an elapsed-time heuristic.
    std::lock_guard<std::mutex> lock(mutex);
    cached.menuReady = false;
    if (!command.empty()) {
        command.clear();
        cached.feedback = "Kod nije primenjen. Vrati se u meni igre.";
    }
}

void beginMovie() {
    ++movieDepth;
    std::lock_guard<std::mutex> lock(mutex);
    cached.menuReady = false;
    if (!command.empty()) {
        command.clear();
        cached.feedback = "Kod nije primenjen tokom videa. Vrati se u meni igre.";
    }
}

void endMovie() { --movieDepth; }

void frontendTick(win32::WinApplication* app, x86::CPU& cpu) {
    if (processing) return; // Original PIONEER opens a nested frontend dialog.
    processing = true;
    std::string request;
    {
        std::lock_guard<std::mutex> lock(mutex);
        expire();
        if (!command.empty()) {
            if (menuReady(app) && singleRace(app)) {
                request = std::move(command);
                command.clear();
                executing = true;
            } else {
                command.clear();
                cached.feedback = "Vrati se u meni i izaberi Single Race (lokalno ili dva igrača).";
            }
        }
    }
    if (!request.empty()) {
        const x86::CPU saved = cpu;
        if (request == "night" || request == "cameras") {
            std::lock_guard<std::mutex> lock(mutex);
            if (request == "night") night = true;
            else cameras = true;
        } else if (request == "normalcar" || request == "reset") {
            normalCar(app);
            if (request == "reset") {
                for (unsigned offset = 0; offset < 32; offset += 4)
                    app->getMemory<x86::reg32>(0x4d24f8 + offset) = 0;
                app->getMemory<x86::reg8>(0x4ddeb0) = 0;
                app->getMemory<x86::reg8>(0x4ddecb) = 0;
                std::lock_guard<std::mutex> lock(mutex);
                night = cameras = false;
            }
        } else {
            // Feed the actual original recognizer on the frontend thread. The
            // UI/input thread must remain free for PIONEER's original dialog.
            for (unsigned i = 0; i < 17; ++i) app->getMemory<x86::reg32>(0x4d20d0 + i * 4) = 0;
            app->getMemory<x86::reg32>(0x4bfe88) = 0;
            app->getMemory<x86::reg32>(0x4bfe8c) = 0;
            for (const unsigned char c : request) {
                cpu.eax = c;
                cpu.esp -= 4;
                app->getMemory<x86::reg32>(cpu.esp) = 0;
                app->dynamic_call(0x404df4, cpu);
                if (cpu.terminate) break;
            }
            // The original code only selects a bonus car on its first unlock.
            // A native menu selection should also work on subsequent clicks.
            if (!cpu.terminate && (request == "fzr2000" || request == "tombstone" || request == "bomber")) {
                normalCar(app);
                app->getMemory<x86::reg8>(0x4dde9f) = request == "fzr2000" ? 14 : request == "tombstone" ? 13 : 12;
                app->getMemory<x86::reg32>(0x4bfd90) = 1;
            }
        }
        const bool terminated = cpu.terminate;
        cpu = saved;
        cpu.terminate = cpu.terminate || terminated;
        std::lock_guard<std::mutex> lock(mutex);
        executing = false;
        cached.feedback = request == "reset" ? "Efekti su resetovani. Otključani sadržaj je sačuvan." :
            request == "normalcar" ? "Ponovo se koristi vozilo iz izbora Player One / Player Two." :
            "Primenjeno: " + request + ". Pokreni narednu trku iz menija igre.";
    }
    Snapshot state = readState(app);
    {
        std::lock_guard<std::mutex> lock(mutex);
        state.feedback = cached.feedback;
        cached = std::move(state);
    }
    processing = false;
}

void beginLoadingKeys(win32::WinApplication* app, bool camera) {
    bool armed;
    {
        std::lock_guard<std::mutex> lock(mutex);
        armed = (camera ? cameras : night) && singleRace(app);
    }
    auto& stack = camera ? cameraKeys : nightKeys;
    SavedKeys saved{armed, {0, 0, 0}};
    if (armed) {
        const std::array<x86::reg32, 3> addresses = camera ?
            std::array<x86::reg32, 3>{0x4c85b2, 0x4c85b4, 0x4c85ba} :
            std::array<x86::reg32, 3>{0x4c85b5, 0, 0};
        for (unsigned i = 0; i < (camera ? 3u : 1u); ++i) {
            saved.values[i] = app->getMemory<x86::reg8>(addresses[i]);
            app->getMemory<x86::reg8>(addresses[i]) = 1;
        }
    }
    stack.push_back(saved);
}

void endLoadingKeys(win32::WinApplication* app, bool camera) {
    auto& stack = camera ? cameraKeys : nightKeys;
    const SavedKeys saved = stack.back();
    stack.pop_back();
    if (!saved.applied) return;
    const std::array<x86::reg32, 3> addresses = camera ?
        std::array<x86::reg32, 3>{0x4c85b2, 0x4c85b4, 0x4c85ba} :
        std::array<x86::reg32, 3>{0x4c85b5, 0, 0};
    for (unsigned i = 0; i < (camera ? 3u : 1u); ++i)
        app->getMemory<x86::reg8>(addresses[i]) = saved.values[i];
}
}

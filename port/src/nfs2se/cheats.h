#pragma once
#include <string>
#include <vector>

namespace win32 { class WinApplication; }
namespace x86 { struct CPU; }

namespace nfs2se::cheats {
struct Snapshot {
    bool menuReady = false;
    bool singleRace = false;
    bool pending = false;
    std::string feedback;
    std::vector<std::string> activeCodes;
};
// Native UI only accesses the synchronized cache, never live game memory.
Snapshot snapshot();
bool queue(const std::string& code);
void frontendTick(win32::WinApplication* app, x86::CPU& cpu);
void frontendClosed();
void beginMovie();
void endMovie();
class MoviePlayback {
public:
    MoviePlayback() { beginMovie(); }
    ~MoviePlayback() { endMovie(); }
    MoviePlayback(const MoviePlayback&) = delete;
    MoviePlayback& operator=(const MoviePlayback&) = delete;
};
// Original loading routines use these scoped key overrides for the next race.
void beginLoadingKeys(win32::WinApplication* app, bool cameras);
void endLoadingKeys(win32::WinApplication* app, bool cameras);
class LoadingKeys {
    win32::WinApplication* app;
    bool cameras;
public:
    LoadingKeys(win32::WinApplication* a, bool c) : app(a), cameras(c) { beginLoadingKeys(app, cameras); }
    ~LoadingKeys() { endLoadingKeys(app, cameras); }
    LoadingKeys(const LoadingKeys&) = delete;
    LoadingKeys& operator=(const LoadingKeys&) = delete;
};
#ifdef __APPLE__
void installMenu();
void shutdownMenu();
#endif
}

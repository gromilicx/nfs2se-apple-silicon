#include <cpu.h>
#include <lib/memmap.h>
#include <nfs2se.h>
#include <cheats.h>

#include <algorithm>
#include <array>
#include <cstring>
#include <fstream>
#include <iostream>
#include <map>
#include <sstream>
#include <string>
#include <vector>

// This executable never calls Application::execute(), initializes a window, or
// opens game assets. Each case restores its private copy of the original data.
namespace {
constexpr x86::reg32 kFeed = 0x00ff0100;
constexpr x86::reg32 kCompare = 0x00ff0110;
constexpr x86::reg32 kBridgeTick = 0x00ff0120;
constexpr x86::reg32 kSafeRoutine = 0x00ff0130;
constexpr x86::reg32 kDataStart = 0x4b7000;
constexpr x86::reg32 kDataEnd = 0x548600;
constexpr x86::reg32 kProgress = 0x4d20d0;

struct Field { const char* name; x86::reg32 address; bool byte; };
const Field fields[] = {
    {"chase", 0x4d24f8, false}, {"pioneer", 0x4d2500, false},
    {"rushhour", 0x4d2504, false}, {"rain", 0x4d250c, false},
    {"roadrage", 0x4d2510, false}, {"slip", 0x4d2514, false},
    {"slot_menu", 0x4bfd90, false}, {"slot", 0x4dde9e, true},
    {"unlock_level", 0x4dde9d, true}, {"selected_car", 0x4dde9f, true},
    {"selected_track", 0x4dde90, true}, {"track_unlock", 0x4dde9c, true},
    {"model_player1", 0x4bfcdc, true}, {"model_player2", 0x4bfcdd, true},
};
using State = std::map<std::string, unsigned>;
bool bridgeCpuRestored = false;
x86::reg32 safeRoutineAddress = 0;

State cpuState(const x86::CPU& cpu) {
    return {{"eax", cpu.eax}, {"ebx", cpu.ebx}, {"ecx", cpu.ecx}, {"edx", cpu.edx},
        {"esi", cpu.esi}, {"edi", cpu.edi}, {"ebp", cpu.ebp}, {"esp", cpu.esp},
        {"ecs", cpu.ecs}, {"eds", cpu.eds}, {"ees", cpu.ees}, {"efs", cpu.efs},
        {"egs", cpu.egs}, {"ess", cpu.ess}, {"ip", cpu.ip},
        {"eflags", cpu.flags.eflags}, {"terminate", cpu.terminate}};
}

void bridgeTick(win32::WinApplication* app, x86::CPU& cpu) {
    // Preserve the real runThread stack and thread-storage segment while giving
    // the original recognizer distinct register values that it would overwrite.
    cpu.eax = 0x12345678; cpu.ebx = 0x23456789; cpu.ecx = 0x3456789a;
    cpu.edx = 0x456789ab; cpu.esi = 0x56789abc; cpu.edi = 0x6789abcd;
    cpu.ebp = 0x789abcde; cpu.flags.eflags = 0x00200246;
    const State before = cpuState(cpu);
    nfs2se::cheats::frontendTick(app, cpu);
    bridgeCpuRestored = before == cpuState(cpu);
    cpu.esp += 8;
}

void safeRoutine(win32::WinApplication* app, x86::CPU& cpu) {
    cpu.esp -= 4;
    app->dynamic_call(safeRoutineAddress, cpu);
    cpu.esp += 8;
}

void feed(win32::WinApplication* app, x86::CPU& cpu) {
    const auto address = static_cast<x86::reg32>(app->getMemory<x86::reg32>(cpu.esp + 4));
    const char* code = &app->getMemory<char>(address);
    for (const unsigned char* c = reinterpret_cast<const unsigned char*>(code); *c; ++c) {
        cpu.eax = *c; // Original input routine consumes one character, not a string.
        cpu.esp -= 4;
        app->dynamic_call(0x404df4, cpu);
        if (cpu.terminate) return;
    }
    cpu.esp += 8;
}

void compare(win32::WinApplication* app, x86::CPU& cpu) {
    const auto address = static_cast<x86::reg32>(app->getMemory<x86::reg32>(cpu.esp + 4));
    const char* code = &app->getMemory<char>(address);
    // PIONEER normally displays an in-game modal dialog before setting its flag.
    // Test its original recognizer without invoking that resource/UI-dependent path.
    const auto table = static_cast<x86::reg32>(app->getMemory<x86::reg32>(0x4bfe44 + 4 * 4));
    for (const unsigned char* c = reinterpret_cast<const unsigned char*>(code); *c; ++c) {
        cpu.eax = *c;
        cpu.ebx = table;
        cpu.edx = kProgress + 4 * 4;
        cpu.esp -= 4;
        app->dynamic_call(0x4052a0, cpu);
        if (cpu.terminate) return;
    }
    cpu.esp += 8;
}

State readState(nfs2se::Application& app) {
    State result;
    for (const auto& f : fields) result[f.name] = f.byte
        ? static_cast<unsigned>(app.getMemory<x86::reg8>(f.address))
        : static_cast<unsigned>(app.getMemory<x86::reg32>(f.address));
    return result;
}

std::string quote(const std::string& text) {
    std::string out = "\"";
    for (const char c : text) {
        if (c == '\\' || c == '"') out += '\\';
        out += c;
    }
    return out + '"';
}

void writeState(std::ostream& out, const State& state) {
    out << '{';
    bool first = true;
    for (const auto& [name, value] : state) {
        if (!first) out << ',';
        first = false;
        out << quote(name) << ':' << value;
    }
    out << '}';
}

struct Result {
    std::string name;
    std::string code;
    std::string scope = "original_handler_state";
    bool passed = false;
    bool recognized = false;
    std::string note;
    State before, expected, after;
};
}

int main(int argc, char** argv) {
    if (argc != 2) { std::cerr << "Usage: cheat_probe results.json\n"; return 2; }
    nfs2se::Application app("isolated-cheat-probe.exe");
    app.registerMethod(kFeed, {"headless test character adapter", &feed});
    app.registerMethod(kCompare, {"headless test PIONEER recognizer", &compare});
    app.registerMethod(kBridgeTick, {"headless native cheat bridge tick", &bridgeTick});
    app.registerMethod(kSafeRoutine, {"headless pure-memory original routine", &safeRoutine});
    // The original sound API explicitly returns early when this init flag is 0.
    app.getMemory<x86::reg8>(0x4cab6c) = 0;
    app.getMemory<x86::reg8>(0x4dde89) = 0;
    app.getMemory<x86::reg8>(0x4dde8a) = 0;
    for (const auto& f : fields) {
        if (f.byte) app.getMemory<x86::reg8>(f.address) = 0;
        else app.getMemory<x86::reg32>(f.address) = 0;
    }
    app.getMemory<x86::reg8>(0x4bfcdc) = 255;
    app.getMemory<x86::reg8>(0x4bfcdd) = 255;
    std::vector<x86::reg8> baseline(kDataEnd - kDataStart);
    std::memcpy(baseline.data(), &app.getMemory<x86::reg8>(kDataStart), baseline.size());
    auto reset = [&] { std::memcpy(&app.getMemory<x86::reg8>(kDataStart), baseline.data(), baseline.size()); };
    auto run = [&](const std::string& code, x86::reg32 entry = kFeed) {
        win32::MemMap input(static_cast<x86::reg32>(code.size() + 1));
        std::memcpy(&app.getMemory<char>(input.getBlockStart()), code.c_str(), code.size() + 1);
        x86::CPU cpu{};
        app.runThread(cpu, entry, input.getBlockStart());
        return !cpu.terminate;
    };

    const std::vector<std::string> names = {"FZR2000", "TOMBSTONE", "BOMBER", "HOLLYWOOD", "PIONEER", "SLIP", "SLOT", "MAD", "RAIN", "CHASE", "KCJONES", "RUSHHOUR", "REXHOUR", "MADLAND", "SCHOOLZONE", "VIP", "ROADRAGE"};
    std::vector<std::string> decoded;
    bool tableMatches = true;
    for (unsigned i = 0; i < names.size(); ++i) {
        auto address = static_cast<x86::reg32>(app.getMemory<x86::reg32>(0x4bfe44 + i * 4));
        std::string code;
        for (unsigned length = 0; length < 32; ++length) {
            const auto c = static_cast<x86::reg8>(app.getMemory<x86::reg8>(address + length));
            if (!c) break;
            code += static_cast<char>(c - 9);
        }
        decoded.push_back(code);
        tableMatches &= code == names[i];
    }

    std::vector<Result> results;
    for (unsigned i = 0; i < names.size(); ++i) {
        reset();
        Result r;
        r.name = "typed_" + names[i]; r.code = names[i]; r.before = readState(app); r.expected = r.before;
        const auto set = [&](const char* key, unsigned value = 1) { r.expected[key] = value; };
        if (i < 3) { set("unlock_level", 3 - i); set("selected_car", 14 - i); }
        if (i == 3) { set("selected_track", 7); set("track_unlock"); }
        if (i == 5) set("slip");
        if (i == 6) { set("slot"); set("slot_menu"); }
        if (i == 8) set("rain");
        if (i == 9) set("chase");
        if (i == 11) set("rushhour");
        if (i >= 12 && i <= 15) {
            const unsigned model = i == 12 ? 43 : i == 13 ? 42 : i == 14 ? 20 : 35;
            set("model_player1", model); set("model_player2", model); set("rushhour");
            if (i > 12) set("pioneer");
        }
        if (i == 16) set("roadrage");
        const bool completed = run(r.code, i == 4 ? kCompare : kFeed);
        r.recognized = static_cast<unsigned>(app.getMemory<x86::reg32>(kProgress + i * 4)) == r.code.size();
        r.after = readState(app);
        r.passed = completed && r.recognized && r.after == r.expected;
        if (i == 4) {
            r.scope = "original_recognizer_only";
            r.note = "PIONEER recognition executed; activation flag and modal notification require initialized game resources and were not executed headlessly.";
        } else if (i == 7 || i == 10) {
            r.note = "Recognized by original table; handler intentionally has no effect in this software-rendered executable.";
        }
        results.push_back(r);
    }
    for (unsigned model = 18; model <= 51; ++model) {
        reset();
        Result r; r.name = "model_GO" + std::to_string(model); r.code = "GO" + std::to_string(model);
        r.before = readState(app); r.expected = r.before;
        const bool bus = model == 18 || model == 22 || model == 24 || model == 25 || model == 29 || model == 30 || model == 32;
        r.expected["model_player1"] = r.expected["model_player2"] = bus ? 20 : model;
        const bool completed = run(r.code);
        r.after = readState(app); r.recognized = r.after["model_player1"] != 255;
        r.passed = completed && r.recognized && r.after == r.expected;
        if (bus) r.note = "Original parser remaps this code to model20 (school bus).";
        if (model == 37 || model == 38 || model == 39) r.note = "Parser preserves this model ID; its asset table later resolves to school bus.";
        results.push_back(r);
    }
    const std::vector<std::string> invalid = {"red racer", "rexrage", "SIL SPD", "FZR20X0", "GO17", "GO52", "GO00", "GO99", "GO1X", "GOX1", "notacode", ""};
    for (const auto& code : invalid) {
        reset(); Result r; r.name = "rejected_" + code; r.code = code;
        r.before = readState(app); r.expected = r.before;
        const bool completed = run(code); r.after = readState(app);
        r.passed = completed && r.after == r.expected;
        r.note = "No cheat-state change from this input; SIL SPD belongs to a separate record-name trigger.";
        results.push_back(r);
    }
    for (const auto& code : {std::string("FZR2000"), std::string("GO43")}) {
        for (unsigned guard = 0; guard < 3; ++guard) {
            reset(); Result r; r.name = "guard_" + code + "_" + std::to_string(guard); r.code = code;
            if (guard < 2) app.getMemory<x86::reg8>(0x4dde89) = guard == 0 ? 2 : 255;
            else app.getMemory<x86::reg8>(0x4dde8a) = 1;
            r.before = readState(app); r.expected = r.before;
            const bool completed = run(code); r.after = readState(app);
            r.passed = completed && r.after == r.expected;
            r.note = guard < 2 ? "Communication mode outside local/split-screen rejects input." : "Tournament race type blocks typed input.";
            results.push_back(r);
        }
    }
    reset();
    {
        Result r; r.name = "split_screen_accepts_FZR2000"; r.code = "fzr2000";
        app.getMemory<x86::reg8>(0x4dde89) = 1;
        r.before = readState(app); r.expected = r.before;
        r.expected["unlock_level"] = 3; r.expected["selected_car"] = 14;
        const bool completed = run(r.code); r.after = readState(app);
        r.recognized = r.after["unlock_level"] == 3;
        r.passed = completed && r.after == r.expected;
        r.note = "Lowercase input is uppercased by the original routine; split-screen communication is allowed.";
        results.push_back(r);
    }

    // Native API tests use only a private Application. Fake nonzero frontend
    // canvases are readiness markers; they are never dereferenced by the bridge.
    namespace cheats = nfs2se::cheats;
    auto nativeResult = [&](const std::string& name, bool passed, const std::string& note) {
        Result r; r.name = "native_" + name; r.scope = "native_bridge_api";
        r.passed = passed; r.note = note; results.push_back(r);
    };
    auto publish = [&] { x86::CPU dummy{}; cheats::frontendTick(&app, dummy); };
    auto liveMenu = [&] {
        app.getMemory<x86::reg32>(0x4d58b8) = 1;
        app.getMemory<x86::reg32>(0x4d58bc) = 1;
        app.getMemory<x86::reg8>(0x4dde89) = 0;
        app.getMemory<x86::reg8>(0x4dde8a) = 0;
        publish();
    };
    auto runBridge = [&] {
        x86::CPU cpu{}; bridgeCpuRestored = false;
        app.runThread(cpu, kBridgeTick, 0);
        return !cpu.terminate && bridgeCpuRestored && !cheats::snapshot().pending;
    };
    auto execute = [&](const std::string& code) { return cheats::queue(code) && runBridge(); };
    bool setupOkay = true;
    auto prepare = [&] {
        reset(); liveMenu();
        setupOkay = execute("reset");
    };
    auto active = [](const cheats::Snapshot& state, const std::string& code) {
        return std::find(state.activeCodes.begin(), state.activeCodes.end(), code) != state.activeCodes.end();
    };
    nativeResult("initial_cache_rejects_queue", !cheats::snapshot().menuReady && !cheats::queue("fzr2000"),
        "A native request is rejected before any initialized frontend tick.");
    reset(); app.getMemory<x86::reg32>(0x4d58b8) = 0; app.getMemory<x86::reg32>(0x4d58bc) = 0; publish();
    nativeResult("missing_canvases_reject_queue", !cheats::snapshot().menuReady && !cheats::queue("go43"),
        "A shared input tick without frontend canvases does not make the menu ready.");
    app.getMemory<x86::reg32>(0x4d58b8) = 1; publish();
    nativeResult("one_canvas_rejects_queue", !cheats::snapshot().menuReady && !cheats::queue("rain"),
        "Both frontend canvas markers are required.");
    liveMenu();
    nativeResult("ready_single_race_snapshot", cheats::snapshot().menuReady && cheats::snapshot().singleRace,
        "A live local Single Race frontend publishes an enabled synchronized snapshot.");
    {
        cheats::MoviePlayback movie;
        nativeResult("movie_immediately_blocks_queue", !cheats::snapshot().menuReady && !cheats::queue("go43"),
            "Showroom/movie entry invalidates cached readiness immediately even while frontend canvases remain allocated.");
        publish();
        nativeResult("movie_input_tick_stays_disabled", !cheats::snapshot().menuReady && !cheats::queue("fzr2000"),
            "Input polling during movie playback cannot enable native cheat activation.");
        {
            cheats::MoviePlayback nestedMovie;
            publish();
        }
        publish();
        nativeResult("nested_movie_scope_keeps_outer_guard", !cheats::snapshot().menuReady && !cheats::queue("rain"),
            "Exiting an inner playback scope keeps the outer playback restriction active.");
    }
    nativeResult("movie_exit_waits_for_frontend_tick", !cheats::snapshot().menuReady && !cheats::queue("go43"),
        "Movie exit does not reuse a stale pre-playback menu snapshot.");
    publish();
    nativeResult("movie_exit_recovers_on_frontend_tick", cheats::snapshot().menuReady && execute("go43") &&
        app.getMemory<x86::reg8>(0x4bfcdc) == 43 && app.getMemory<x86::reg8>(0x4bfcdd) == 43,
        "A subsequent live frontend tick re-enables requests and the original GO43 effect executes normally.");
    prepare();
    {
        const State before = readState(app);
        const bool queued = cheats::queue("go43");
        bool canceled;
        {
            cheats::MoviePlayback movie;
            canceled = !cheats::snapshot().pending && !cheats::snapshot().menuReady;
            publish();
        }
        publish();
        nativeResult("movie_entry_cancels_pending_request", setupOkay && queued && canceled &&
            !cheats::snapshot().pending && readState(app) == before,
            "A command queued immediately before playback is canceled and is never replayed on returning to the menu.");
    }
    cheats::frontendClosed();
    nativeResult("frontend_close_immediately_blocks_queue", !cheats::snapshot().menuReady && !cheats::queue("go43"),
        "Original frontend teardown invalidates cached readiness immediately without waiting for another input tick.");
    prepare();
    {
        const State before = readState(app);
        const bool queued = cheats::queue("go43");
        cheats::frontendClosed();
        cheats::frontendClosed(); // Repeated cleanup notification is harmless.
        nativeResult("frontend_close_cancels_pending_request", setupOkay && queued &&
            !cheats::snapshot().menuReady && !cheats::snapshot().pending && !cheats::queue("normalcar") && readState(app) == before,
            "Frontend teardown cancels a pending request; repeated notifications do not replay or apply it.");
        publish();
        nativeResult("frontend_close_recovers_on_next_tick", cheats::snapshot().menuReady &&
            !cheats::snapshot().pending && readState(app) == before && execute("go43") &&
            app.getMemory<x86::reg8>(0x4bfcdc) == 43 && app.getMemory<x86::reg8>(0x4bfcdd) == 43,
            "A fresh initialized frontend tick restores activation, while the previously canceled command stays canceled.");
    }
    for (unsigned comm : {2u, 3u, 4u, 255u}) {
        app.getMemory<x86::reg8>(0x4dde89) = comm; publish();
        nativeResult("communication_guard_" + std::to_string(comm), !cheats::snapshot().singleRace && !cheats::queue("go43"),
            "The bridge preserves the original local/split-screen communication restriction.");
    }
    for (unsigned race : {1u, 2u, 3u, 255u}) {
        liveMenu(); app.getMemory<x86::reg8>(0x4dde8a) = race; publish();
        nativeResult("race_type_guard_" + std::to_string(race), !cheats::snapshot().singleRace && !cheats::queue("fzr2000"),
            "The bridge requires Single Race, independently of communication mode.");
    }
    liveMenu();
    for (const auto& code : {"mad", "kcjones", "rexrage", "red racer", "go17", "go52", "go99", "go1x", "GO43", "", "notacode"}) {
        nativeResult("reject_" + std::string(code), !cheats::queue(code) && !cheats::snapshot().pending,
            "The native bridge accepts only its explicit canonical command whitelist; renderer no-ops are excluded.");
    }
    std::vector<std::string> allowed = {"fzr2000", "tombstone", "bomber", "hollywood", "pioneer", "slip", "slot", "rain", "chase", "rushhour", "rexhour", "madland", "schoolzone", "vip", "roadrage", "night", "cameras", "normalcar", "reset"};
    for (unsigned id = 18; id <= 51; ++id) allowed.push_back("go" + std::to_string(id));
    for (const auto& code : allowed) {
        liveMenu();
        const bool accepted = cheats::queue(code) && cheats::snapshot().pending;
        const bool secondRejected = !cheats::queue("normalcar");
        // Cancel through a missing-menu tick, including PIONEER, so whitelist
        // coverage does not invoke any resource-dependent modal notification.
        app.getMemory<x86::reg32>(0x4d58b8) = 0; publish();
        nativeResult("whitelist_" + code, accepted && secondRejected && !cheats::snapshot().pending,
            "Whitelisted command queues once; a second pending request is rejected; losing the frontend cancels safely.");
    }
    prepare();
    {
        const State before = readState(app);
        const bool accepted = cheats::queue("go43");
        app.getMemory<x86::reg8>(0x4dde8a) = 1; publish();
        nativeResult("rechecks_mode_before_execution", setupOkay && accepted && !cheats::snapshot().pending && readState(app) == before,
            "Changing to Tournament after queueing cancels the command before original-handler execution.");
    }
    for (const auto& code : {std::string("fzr2000"), std::string("tombstone"), std::string("bomber")}) {
        prepare();
        app.getMemory<x86::reg8>(0x4dde9d) = 3;
        app.getMemory<x86::reg8>(0x4dde9f) = 5;
        app.getMemory<x86::reg8>(0x4bfcdc) = 43;
        app.getMemory<x86::reg8>(0x4bfcdd) = 42;
        Result r; r.name = "native_reselect_unlocked_" + code; r.code = code; r.scope = "native_bridge_state";
        r.before = readState(app); r.expected = r.before;
        r.expected["selected_car"] = code == "fzr2000" ? 14 : code == "tombstone" ? 13 : 12;
        r.expected["model_player1"] = r.expected["model_player2"] = 0; r.expected["slot_menu"] = 1;
        const bool completed = execute(code); r.after = readState(app);
        r.passed = setupOkay && completed && r.after == r.expected && active(cheats::snapshot(), code);
        r.note = "Native selection reselects an already unlocked bonus car, clears both GO overrides to0, requests car-panel refresh and restores all CPU registers.";
        results.push_back(r);
    }
    prepare();
    {
        const bool first = execute("go43"), second = execute("go20"), third = execute("go43");
        nativeResult("repeated_commands_clear_matcher_progress", setupOkay && first && second && third &&
            app.getMemory<x86::reg8>(0x4bfcdc) == 43 && app.getMemory<x86::reg8>(0x4bfcdd) == 43 && active(cheats::snapshot(), "go43"),
            "Alternating and repeating GO requests execute independently without stale original recognizer progress.");
        app.getMemory<x86::reg8>(0x4dde9f) = 4; app.getMemory<x86::reg8>(0x4ddeba) = 9;
        const bool normal = execute("normalcar");
        nativeResult("normalcar_restores_both_selections", normal && app.getMemory<x86::reg8>(0x4bfcdc) == 0 &&
            app.getMemory<x86::reg8>(0x4bfcdd) == 0 && app.getMemory<x86::reg8>(0x4dde9f) == 4 && app.getMemory<x86::reg8>(0x4ddeba) == 9,
            "Normal car clears both overrides while retaining the independently selected player/opponent car IDs.");
    }
    prepare();
    {
        bool completed = true;
        for (const auto& code : {"slip", "rain", "chase", "rushhour", "roadrage", "slot"}) completed = execute(code) && completed;
        const auto enabled = cheats::snapshot();
        bool reflectsFlags = true;
        for (const auto& code : {"slip", "rain", "chase", "rushhour", "roadrage", "slot"}) reflectsFlags = reflectsFlags && active(enabled, code);
        const bool repeated = execute("slip") && execute("slip");
        nativeResult("effect_snapshot_and_one_way_reentry", setupOkay && completed && reflectsFlags && repeated && app.getMemory<x86::reg32>(0x4d2514) == 1,
            "Snapshot mirrors enabled original flags, and repeating SLIP retains the one-way original activation semantics.");
    }
    prepare();
    {
        const std::array<x86::reg32, 4> keys = {0x4c85b5, 0x4c85b2, 0x4c85b4, 0x4c85ba};
        for (unsigned i = 0; i < keys.size(); ++i) app.getMemory<x86::reg8>(keys[i]) = static_cast<x86::reg8>(i + 2);
        {
            cheats::LoadingKeys inactiveNight(&app, false), inactiveCameras(&app, true);
            bool unchanged = true;
            for (unsigned i = 0; i < keys.size(); ++i) unchanged &= app.getMemory<x86::reg8>(keys[i]) == i + 2;
            nativeResult("unarmed_loading_keys_are_unchanged", setupOkay && unchanged,
                "Loading scopes leave physical key state untouched until their corresponding menu actions are armed.");
        }
        const bool armed = execute("night") && execute("cameras");
        const auto state = cheats::snapshot();
        bool pressed = false, nestedRestored = false;
        {
            cheats::LoadingKeys nightScope(&app, false), cameraScope(&app, true);
            pressed = true;
            for (auto address : keys) pressed &= app.getMemory<x86::reg8>(address) == 1;
            {
                cheats::LoadingKeys nestedNight(&app, false), nestedCamera(&app, true);
                for (auto address : keys) app.getMemory<x86::reg8>(address) = 0;
            }
            nestedRestored = true;
            for (auto address : keys) nestedRestored &= app.getMemory<x86::reg8>(address) == 1;
        }
        bool restored = true;
        for (unsigned i = 0; i < keys.size(); ++i) restored &= app.getMemory<x86::reg8>(keys[i]) == i + 2;
        nativeResult("armed_loading_keys_scope_and_nested_restore", armed && active(state, "night") && active(state, "cameras") && pressed && nestedRestored && restored,
            "Arming changes snapshot state; scoped N/C/B/RightShift overrides restore every prior key byte, including nested scopes.");
        for (unsigned guard = 0; guard < 2; ++guard) {
            app.getMemory<x86::reg8>(0x4dde89) = guard == 0 ? 2 : 0;
            app.getMemory<x86::reg8>(0x4dde8a) = guard == 0 ? 0 : 1;
            bool unchanged = true;
            {
                cheats::LoadingKeys guardedNight(&app, false), guardedCameras(&app, true);
                for (unsigned i = 0; i < keys.size(); ++i) unchanged &= app.getMemory<x86::reg8>(keys[i]) == i + 2;
            }
            nativeResult("armed_loading_keys_respect_mode_" + std::to_string(guard), unchanged,
                "Armed loading overrides are suppressed outside local/split-screen Single Race.");
        }
        liveMenu();
        for (unsigned i = 0; i < 8; ++i) app.getMemory<x86::reg32>(0x4d24f8 + i * 4) = 7;
        app.getMemory<x86::reg8>(0x4bfcdc) = 43; app.getMemory<x86::reg8>(0x4bfcdd) = 42;
        app.getMemory<x86::reg8>(0x4dde9d) = 3; app.getMemory<x86::reg8>(0x4dde9c) = 5;
        app.getMemory<x86::reg8>(0x4dde9e) = 1;
        app.getMemory<x86::reg8>(0x4ddeb0) = 1; app.getMemory<x86::reg8>(0x4ddecb) = 1;
        const bool cleared = execute("reset");
        bool flagsClear = true;
        for (unsigned i = 0; i < 8; ++i) flagsClear &= app.getMemory<x86::reg32>(0x4d24f8 + i * 4) == 0;
        const auto resetState = cheats::snapshot();
        nativeResult("reset_clears_effects_preserves_unlocks", cleared && flagsClear && app.getMemory<x86::reg8>(0x4bfcdc) == 0 &&
            app.getMemory<x86::reg8>(0x4bfcdd) == 0 && app.getMemory<x86::reg8>(0x4dde9d) == 3 &&
            app.getMemory<x86::reg8>(0x4dde9c) == 5 && app.getMemory<x86::reg8>(0x4dde9e) == 1 &&
            app.getMemory<x86::reg8>(0x4ddeb0) == 0 && app.getMemory<x86::reg8>(0x4ddecb) == 0 &&
            !active(resetState, "night") && !active(resetState, "cameras") && active(resetState, "fzr2000") && active(resetState, "hollywood") && active(resetState, "slot"),
            "Reset clears all8 original transient fields, both model overrides, active Slot selections and loading arms while retaining bonus/track/Slot availability.");
    }
    for (unsigned i = 0; i < 3; ++i) {
        reset(); Result r; r.name = "already_unlocked_" + names[i]; r.code = names[i];
        app.getMemory<x86::reg8>(0x4dde9d) = 3;
        app.getMemory<x86::reg8>(0x4dde9f) = 5;
        r.before = readState(app); r.expected = r.before;
        const bool completed = run(r.code); r.after = readState(app);
        r.recognized = static_cast<unsigned>(app.getMemory<x86::reg32>(kProgress + i * 4)) == r.code.size();
        r.passed = completed && r.recognized && r.after == r.expected;
        r.note = "Original cheat does not reselect a bonus car after its unlock threshold is already met.";
        results.push_back(r);
    }
    for (const auto& code : {std::string("slip"), std::string("slot"), std::string("rain"), std::string("chase"), std::string("rushhour"), std::string("roadrage")}) {
        reset(); Result r; r.name = "repeat_is_one_way_" + code; r.code = code;
        const bool first = run(code);
        r.before = readState(app); r.expected = r.before;
        const bool completed = run("#" + code);
        r.after = readState(app); r.passed = first && completed && r.after == r.expected;
        r.note = "A separator resets the original input progress; re-entry leaves the enabled flag at1.";
        results.push_back(r);
    }

    auto runSafe = [&](x86::reg32 address) {
        safeRoutineAddress = address;
        x86::CPU cpu{}; app.runThread(cpu, kSafeRoutine, 0);
        return !cpu.terminate;
    };
    // These original loading functions have only memory/math side effects;
    // unlike races they require no window, asset files or preferences.
    prepare();
    {
        app.getMemory<x86::reg8>(0x4c85b5) = 0;
        app.getMemory<x86::reg8>(0x519580) = 91;
        app.getMemory<x86::reg8>(0x519581) = 92;
        app.getMemory<x86::reg8>(0x519582) = 93;
        const bool armed = execute("night");
        bool completed;
        {
            cheats::LoadingKeys nightScope(&app, false);
            completed = runSafe(0x470d10);
        }
        const State expected = {{"red", 0}, {"green", 0}, {"blue", 0},
            {"range0", 0}, {"range1", 0}, {"range2", 12}, {"range3", 15},
            {"range4", 0}, {"range5", 80}, {"range6", 85}, {"range7", 300},
            {"horizon_enabled", 1}, {"light0", 10}, {"light1", 10}, {"light2", 10}, {"light3", 0},
            {"sky_mode", 2}, {"physical_n", 0}};
        State after = {{"red", app.getMemory<x86::reg8>(0x519580)}, {"green", app.getMemory<x86::reg8>(0x519581)},
            {"blue", app.getMemory<x86::reg8>(0x519582)}, {"horizon_enabled", app.getMemory<x86::reg32>(0x51957c)},
            {"light0", app.getMemory<x86::reg32>(0x517b8c)}, {"light1", app.getMemory<x86::reg32>(0x517b90)},
            {"light2", app.getMemory<x86::reg32>(0x517b94)}, {"light3", app.getMemory<x86::reg32>(0x517b98)},
            {"sky_mode", app.getMemory<x86::reg32>(0x4dc890)}, {"physical_n", app.getMemory<x86::reg8>(0x4c85b5)}};
        for (unsigned i = 0; i < 8; ++i) after["range" + std::to_string(i)] = app.getMemory<x86::reg32>(0x519494 + i * 4);
        Result r; r.name = "native_night_reaches_original_palette_routine"; r.code = "night";
        r.scope = "original_loading_key_routine"; r.expected = expected; r.after = after;
        r.passed = setupOkay && armed && completed && after == expected;
        r.note = "Scoped native N override executes original470d10: exact horizon/lighting/sky globals change, then the previous physical N byte is restored.";
        results.push_back(r);
    }
    for (unsigned held = 0; held < 8; ++held) {
        reset();
        win32::MemMap car(0x684);
        std::memset(&app.getMemory<x86::reg8>(car.getBlockStart()), 0, car.getBlockSize());
        app.getMemory<x86::reg32>(0x4dcde8) = car.getBlockStart();
        for (auto address : {0x4dd2e8u, 0x4dd2ecu, 0x4dd2d8u, 0x4dd308u}) app.getMemory<x86::reg32>(address) = 0;
        app.getMemory<x86::reg8>(0x4c85b2) = (held & 1) != 0;
        app.getMemory<x86::reg8>(0x4c85b4) = (held & 2) != 0;
        app.getMemory<x86::reg8>(0x4c85ba) = (held & 4) != 0;
        const bool completed = runSafe(0x439320);
        const std::array<unsigned, 13> normal = {1, 2, 3, 0, 5, 6, 7, 0, 0, 0, 0, 0, 6};
        State expected, after;
        for (unsigned i = 0; i < normal.size(); ++i) {
            expected["next_camera_" + std::to_string(i)] = i == 3 && (held == 5 || held == 7) ? 4 :
                i == 3 && held == 6 ? 8 : i == 7 && held == 7 ? 8 : normal[i];
            after["next_camera_" + std::to_string(i)] = app.getMemory<x86::reg8>(0x4dc9f9 + i);
        }
        Result r; r.name = "original_camera_key_permutation_" + std::to_string(held); r.code = "C+B+RightShift";
        r.scope = "original_loading_key_routine"; r.expected = expected; r.after = after;
        r.passed = completed && after == expected;
        r.note = "Original439320: C+RightShift sets link3=4; B+RightShift alone sets link3=8; all three set link3=4 and link7=8. A zeroed isolated car supplies its memory dependencies.";
        results.push_back(r);
    }
    prepare();
    {
        win32::MemMap car(0x684);
        std::memset(&app.getMemory<x86::reg8>(car.getBlockStart()), 0, car.getBlockSize());
        app.getMemory<x86::reg32>(0x4dcde8) = car.getBlockStart();
        for (auto address : {0x4dd2e8u, 0x4dd2ecu, 0x4dd2d8u, 0x4dd308u}) app.getMemory<x86::reg32>(address) = 0;
        const std::array<x86::reg32, 3> keys = {0x4c85b2, 0x4c85b4, 0x4c85ba};
        for (auto address : keys) app.getMemory<x86::reg8>(address) = 0;
        const bool armed = execute("cameras");
        bool completed;
        {
            cheats::LoadingKeys cameraScope(&app, true);
            completed = runSafe(0x439320);
        }
        bool restored = true;
        for (auto address : keys) restored &= app.getMemory<x86::reg8>(address) == 0;
        nativeResult("cameras_reaches_original_camera_table", setupOkay && armed && completed && restored &&
            app.getMemory<x86::reg8>(0x4dc9fc) == 4 && app.getMemory<x86::reg8>(0x4dca00) == 8,
            "Native camera arming supplies the exact three-key original trigger, opens both extra camera links and restores all physical key bytes afterward.");
    }

    unsigned passed = 0;
    for (const auto& r : results) {
        passed += r.passed;
        if (!r.passed) std::cerr << "FAIL " << r.name << '\n';
    }
    std::ofstream out(argv[1]);
    if (!out) { std::cerr << "Cannot write result file\n"; return 2; }
    out << "{\n\"schema\":2,\n\"scope\":\"Isolated ARM64 execution of original translated input handler, native bridge queue/snapshots/loading scopes and pure-memory original night/camera routines; no game assets, window, preferences, race rendering or visual gameplay were used.\",\n";
    out << "\"limitations\":[\"PIONEER tested through original recognizer and native whitelist only because its activation opens a resource-dependent modal dialog.\",\"MAD and KCJONES are accepted original no-op entries in this software-rendered executable.\",\"In-race driving/rendering, heavier-car record entry and barrier-jump triggers require separate runtime or source verification.\"],\n";
    out << "\"original_table_matches\":" << (tableMatches ? "true" : "false") << ",\n\"original_table\":[";
    for (unsigned i = 0; i < decoded.size(); ++i) { if (i) out << ','; out << quote(decoded[i]); }
    out << "],\n\"passed\":" << passed << ",\n\"total\":" << results.size() << ",\n\"tests\":[\n";
    for (unsigned i = 0; i < results.size(); ++i) {
        const auto& r = results[i];
        if (i) out << ",\n";
        out << "{\"name\":" << quote(r.name) << ",\"code\":" << quote(r.code)
            << ",\"scope\":" << quote(r.scope) << ",\"passed\":" << (r.passed ? "true" : "false")
            << ",\"recognized\":" << (r.recognized ? "true" : "false") << ",\"note\":" << quote(r.note) << ",\"before\":";
        writeState(out, r.before); out << ",\"expected\":"; writeState(out, r.expected);
        out << ",\"after\":"; writeState(out, r.after); out << '}';
    }
    out << "\n]}\n";
    std::cout << passed << '/' << results.size() << " headless cases passed; original table " << (tableMatches ? "matched" : "MISMATCH") << '\n';
    return passed == results.size() && tableMatches ? 0 : 1;
}

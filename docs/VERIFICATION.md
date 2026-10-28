# Verification record

Recorded October 28, 2026, on an M3 Pro Mac running macOS 27.0.

## Build and packaging

The build verifies ARM64 architecture for launcher/runtime, checks dylib
dependencies, bundles SDL3, validates the plist, signs locally, and runs
`codesign --verify --deep --strict`. This does not provide Apple notarization.

## Isolated tests

`./scripts/test-cheats.sh` links the actual runtime objects into a separate probe.
It does not run the full game, create a window, load assets, or read user saves.
Recorded result: **186/186 passing checks**.

Coverage includes all 17 decoded original table entries, 34 GO codes, invalid
inputs, communication/race-mode restrictions, lowercase input, repeated flags,
original bonus unlock behavior, native bonus reselection, ordinary-car restoration,
reset/unlock preservation, CPU-state restoration, queue validation, frontend
teardown, nested movies, original night setup, all camera-key combinations, and
scoped key restoration.

The headless PIONEER case checks its recognizer only: full activation opens a
resource-dependent modal dialog. Its actual activation and message were checked
in the running game. MAD/KCJONES are tested as recognized no-op entries in this
software executable, not as working 3Dfx effects.

Machine-readable records:

- [Automated results](cheats-test-results.json)
- [Typed-code audit](cheats-audit-typed.json)
- [Special-trigger audit](cheats-audit-special.json)
- [Manual runtime checks](cheats-runtime-checks.json)

## Runtime checks

Initial port checks covered intro playback, menus, mouse selection (also confirmed
by the user), track selection, sound/graphics submenus, Proving Grounds loading,
acceleration, automatic shifting, pause, normal exit/config writes, restart,
Command-Q, and resizing.

Version 1.2 was checked on isolated game data: F12, initial row selection, search,
readiness while the panel has focus, FZR 2000's original preview, PIONEER's original
message/status, reset, a night race, and disabled activation during a race. The
test instance quit through Command-Q. The final local app was also launched and
its panel opened successfully.

## Limits

Every model, track, physical effect, sound, and controller has not been tested.
The original nine-camera setup was executed in tests, but all nine views were not
manually compared. H turbo and full record-name entry/persistence are unverified.
Network play is not supported. These results describe the tested configuration,
not every Apple Silicon Mac or OS version.

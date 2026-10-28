# Need for Speed II SE on Apple Silicon

Build and run **Need for Speed II Special Edition natively on an Apple Silicon Mac**.

This repository contains macOS/ARM64 adaptations for
[motor-dev/nfs-recompiled](https://github.com/motor-dev/nfs-recompiled), a native
launcher, reproducible build scripts, and a searchable cheat panel with 59 entries.

**You must supply your own game data.** No game assets, Windows installers,
original executable files, music, car models, tracks, or ready-to-play app bundles
are distributed here. The build creates a local app containing your supplied
data; do not redistribute that bundle with commercial assets included.

## What “native” means

The runtime is compiled for ARM64 macOS. It does not use Wine, Rosetta, or a
Windows VM. Upstream translates the original x86 program into C++ that models its
registers and memory. This is not a rewrite of the game or a graphics remaster.
The current port uses the original software renderer, scaled to a 4:3 viewport.

## Status and requirements

| Item | Status |
| --- | --- |
| Tested hardware | M3 Pro Mac, ARM64 |
| Tested OS | macOS 27.0, October 28, 2026 |
| Local app version | 1.2 |
| Tested package minimum OS | macOS 26.0, required by the installed SDL3 dylib |
| Build dependencies | Apple Command Line Tools, Git, CMake, Python 3.9+, pkg-config, SDL3 |
| Tested extraction | innoextract; ZIP with an Inno Setup executable and matching numbered `.bin` volumes |
| Isolated automated checks | 186/186 passing |

Other Apple Silicon models and macOS versions have not been individually tested.
The script derives its deployment target from the installed SDL3 dylib, with a
project floor of macOS 13. A lower target is not a claim of tested compatibility.
Intel Mac builds are outside this guide.

## Build and run

### 1. Install dependencies

Install Apple's Command Line Tools if needed:

```sh
xcode-select --install
```

With [Homebrew](https://brew.sh/) installed:

```sh
brew install cmake pkg-config python sdl3 innoextract
```

### 2. Fetch the project and pinned source

```sh
git clone https://github.com/gromilicx/nfs2se-apple-silicon.git
cd nfs2se-apple-silicon
./scripts/setup-source.sh
```

Setup fetches specific upstream revisions, applies the port patch, and adds the
new source files. It can be rerun against the same prepared checkout. Conflicting
local edits are rejected instead of being reset or overwritten.
See [source provenance](docs/ARCHITECTURE.md#source-provenance).

### 3. Supply your game data

For the tested installer layout:

```sh
./scripts/extract-game-data.sh "$HOME/Downloads/Need.for.Speed.II.SE.zip"
```

Pass a different ZIP path if necessary. The filename is not important; its
contents must match the supported installer layout. The helper selects the game
setup file and its data volumes, then reads them using `innoextract`.
**It never executes the Windows installer.**

Different releases, arbitrary ZIP layouts, and CD images are not automatically
supported. See the [manual data layout](docs/TROUBLESHOOTING.md#using-an-already-extracted-installation)
if you already have an extracted installation. This project supplies no game download.

### 4. Build and launch

```sh
./scripts/build-macos.sh
open "Need for Speed II SE.app"
```

The script compiles the ARM64 runtime and launcher, bundles SDL3 and your local
game data, checks architecture and dependencies, and applies an ad-hoc signature.
A previous app is preserved in `build/previous-app.*/`. The app is not notarized
or signed with an Apple Developer certificate.

Your locally built app can be moved to Applications. It contains its runtime
library and data, so launching it does not require the build checkout or Homebrew.

## Playing

- Enter or Escape skips the introduction.
- Use the mouse in menus, or arrow keys and Enter. Escape goes back.
- Change tracks through **location → track → DONE**.
- Open **options** for audio, controls, and graphics; select **RACE** to start.
- Default driving controls are the arrows; **C** changes camera and **Escape** pauses.
- Confirm changes with **DONE**. **CANCEL** can restore previous settings.

### Hidden cars and cheat panel

Press **F12** (or **Fn+F12**, depending on your keyboard setting), use
**Command+Shift+K**, or select **Kodovi → Skriveni automobili i kodovi…** in the
macOS menu bar. Activate codes from the main menu in local or split-screen
**Single Race**. Activation is disabled during races and movies.

The current panel is in Serbian Latin; this documentation is in English:

| Panel label | Meaning |
| --- | --- |
| Pretraga | Search |
| Aktiviraj / Primeni ponovo | Activate / Apply again |
| Otključano / Aktivno | Unlocked / Active |
| Ukloni efekte | Reset temporary effects, keeping unlocked content |
| Običan automobil | Restore ordinary car selection after a GO override |
| Nazad u igru | Return to the game |

Select **FZR 2000** to unlock and select it. The panel can select it again when
already unlocked, unlike retyping the original code. All `go18`–`go51` entries,
night mode, and nine-camera preparation are listed. Night and camera options
remain prepared for subsequent races until reset or app exit.

Some published cheat lists are inaccurate for this executable: `rexhour` is the
dinosaur code, `slip` changes grip, and `mad`/`kcjones` have no effect in this
software version. Read the [English cheat guide](docs/CHEATS.md) for the full list.

## Saves, settings, and logs

The launcher creates a writable first-run copy at:

```text
~/Library/Application Support/NFS II SE/game-data
```

Rebuilding or moving the app does not replace that directory. The log is:

```text
~/Library/Logs/NFS II SE/game.log
```

Known patched menu text is corrected without replacing saves or configuration.
Only exact matching legacy text files are migrated, with backups under
`~/Library/Application Support/NFS II SE/asset-backups/`. Custom text is preserved.
Back up the support directory before attempting a clean profile.

## Verification and limitations

After building, run:

```sh
./scripts/test-cheats.sh
```

The probe links the actual runtime objects into an isolated process. It does not
open game assets, user saves, or the running game. Recorded result: **186/186**
passing checks. A new run updates the JSON results locally.

Manual checks covered startup, menus, mouse input, track loading, driving,
resizing, exit, FZR 2000 selection, the Pioneer dialog, reset, a night race, and
disabled activation during a race. Every track, model, controller, sound, and
physical cheat effect has **not** been individually tested. Network play is not supported.

- [Verification record](docs/VERIFICATION.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Implementation notes](docs/ARCHITECTURE.md)
- [Third-party notices and license scope](THIRD_PARTY_NOTICES.md)

This is an unofficial compatibility project, not an EA release. Need for Speed
and the original game content belong to their respective owners.

## Credits

- [motor-dev/nfs-recompiled](https://github.com/motor-dev/nfs-recompiled): translated runtime and compatibility layer.
- [zaps166/NFSIISEN](https://github.com/zaps166/NFSIISEN): companion installation metadata.
- [DLTcollab/sse2neon](https://github.com/DLTcollab/sse2neon): ARM vector translation.
- [SDL3](https://github.com/libsdl-org/SDL): platform services.

This repository documents and packages the Apple Silicon adaptations.

# Troubleshooting

## Setup refuses an existing checkout

Setup protects local edits and checks pinned revisions. Inspect the checkout's
diff, preserve your work, and move it aside before retrying. Do not force-reset a
checkout containing changes you need.

## The ZIP cannot be extracted

The helper supports one Inno Setup game executable with matching numbered `.bin`
volumes inside a ZIP. It ignores unrelated redistributable installers and rejects
ambiguous setup files, duplicate names, and symlinks. It does not mount CD images
or support arbitrary repack/archive layouts.

## Using an already-extracted installation

After `setup-source.sh`, prepare this local structure from your own copy:

```text
data/extracted/app/
  FEDATA/
  GAMEDATA/
  NFS2SEN.EXE
  INSTALL.WIN
  text.eng
```

Copy `FEDATA`, `GAMEDATA`, and the original `NFS2SEN.EXE` from your installation.
Prepare the companion metadata used by this build:

```sh
mkdir -p data/extracted/app
cp "source/NFSIISEN/Need For Speed II SE/install.win" data/extracted/app/INSTALL.WIN
cp "source/NFSIISEN/Need For Speed II SE/text.eng" data/extracted/app/text.eng
```

Then run `./scripts/build-macos.sh`. Only the supplied installer layout has been
tested end to end. Other releases may have different executables, assets, or text
tables; these instructions do not establish compatibility with every release.

## macOS version requirements

The build reads SDL3's minimum macOS version with `vtool`. The tested dylib
requires macOS 26. Editing the app plist does not lower a library requirement.
Older systems would require a suitable SDL build and a fresh validation; that
compatibility has not been verified.

## Missing dependencies

Ensure `cmake`, `clang`, `python3`, `pkg-config`, `codesign`, `install_name_tool`,
`rsync`, and `vtool` are available. `pkg-config --modversion sdl3` must succeed.
Use a native ARM64 terminal and native dependencies for this guide.

## Incorrect menu text

Rebuild with the text preparation script present. It adapts the known patched
layout, then the launcher migrates exact matching legacy files with backups.
Custom text is preserved; unknown descriptor counts cause an error. Do not
replace the whole save directory to repair text.

## Controls and cheats

Click the game window for focus. Use F12/Fn+F12 or Command+Shift+K for the panel.
Activate from the main menu in local/split-screen Single Race. Activation during
movies or races is deliberately disabled. Confirm submenu changes with DONE;
CANCEL can restore the previous configuration. Retyping a code does not disable it.

The original FZR code selects the car only when increasing the unlock level;
the panel can select it again. A GO override may change the car used in the race
without changing the old preview. Use “Običan automobil” to clear that override.

## Rebuilt app still uses existing settings

Saves/settings intentionally live outside the app. Only exact-match text repairs
and a missing marker repair are performed. Check
`~/Library/Logs/NFS II SE/game.log` and back up the Application Support directory
before experimenting with a clean profile.

## Reporting an issue

Include the Mac model/chip, macOS and dependency versions, failing step, and a
short relevant log excerpt. Remove private paths or personal information before
posting. Do not attach game assets, installers, original executables, or saves.

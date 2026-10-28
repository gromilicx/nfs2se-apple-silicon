# Architecture

## Source provenance

| Component | Pinned revision | Purpose |
| --- | --- | --- |
| [motor-dev/nfs-recompiled](https://github.com/motor-dev/nfs-recompiled) | `77ebdb3b6a21925ccfc4fc4c1d712abec3e1945a` | Translated original program, virtual CPU, compatibility layer, renderer |
| [zaps166/NFSIISEN](https://github.com/zaps166/NFSIISEN) | `ad73d45c7f2f5f8c384c8b46dd9c82125578e647` | Companion `install.win` and `text.eng` |
| [DLTcollab/sse2neon](https://github.com/DLTcollab/sse2neon) | `2272251cc3ad9cba8b8c47c4065811cfb396b802` | Unmodified MIT-licensed vector translation header |

`source/` is populated locally and ignored by Git. Setup fetches pinned revisions,
applies `patches/apple-silicon.patch`, and copies `port/` into the prepared tree.
The full upstream program and original game binaries/data are not mirrored here.
The vendored SSE2NEON header retains its license and provenance notice.

## Adaptations

- **ARM64 vectors:** upstream's SSE2 representation of MMX operations is
  translated into ARM NEON through SSE2NEON.
- **16 KiB host pages:** the macOS guest-memory arena remains read/write. Original
  4 KiB guest-section protections can overlap differently on Apple Silicon host
  pages. Allocation failure and cleanup ordering are checked.
- **Cocoa main thread:** SDL window creation, OpenGL context operations, mode
  changes, and presentation run on the actual main thread. The translated game
  executes on a worker while the main thread pumps events.
- **Input:** SDL printable text becomes Win32 character messages. Control keys,
  key flags, focus, mouse messages, and buffered DirectInput mouse data are
  implemented. Mouse scaling accounts for the 640×480 canvas and 4:3 viewport.
- **Compatibility:** drive-list encoding/bitmasks, socket macro collisions,
  portable diagnostics, gamepad bounds, and macOS OpenGL headers are corrected.
- **Launcher:** atomic first-run data preparation, save-preserving text migration,
  missing-marker repair, logging, and execution of the ARM64 runtime. The original
  `NFS2SEN.EXE` is retained locally as a data-presence marker, never executed.

## Text compatibility

The tested Windows-patched text tables contain 1,502 descriptors; the translated
original runtime expects 1,498. `prepare-game-text.py` removes source indices
53, 54, 55, and 360, then subtracts 48 from remaining string offsets. It preserves
string content, accepts already-original 1,498-entry tables, and rejects unknown
counts. Seven language tables were converted. The initial investigation compared
156 original/patched instruction references.

The package contains corrected seeds, original copies, and a manifest. The
launcher migrates only files identical to the known original seed, with backups.
Custom text and existing saves/configuration remain intact.

## Cheat bridge

AppKit reads a synchronized host-side snapshot and queues commands. It never
accesses live guest memory. A hook in the original frontend input routine feeds
the actual character recognizer on the game thread. CPU registers, flags, FPU,
and MMX state are restored after injected calls; intended state changes remain.

PIONEER opens an original modal notification. Running it on the frontend thread
leaves the input thread available, while a reentrancy guard blocks nested command
processing. Mode checks, menu canvases, frontend teardown, and a scoped movie
guard control availability. Opening a native panel can pause frontend ticks on
focus loss, so readiness is invalidated at actual teardown rather than a short
inactivity timeout. Queued commands expire and are revalidated before execution.

Night and camera options temporarily hold original guest key bytes around the
original loading routines, restoring prior values on return. Reset clears the
transient flags, GO overrides, and active Slot selections, retaining unlocks.

## Maintaining the port

Keep modifications to upstream files in the patch and new files under `port/`.
Do not commit the populated `source/` tree. Deliberately rebase changes before
updating a pinned revision, then validate setup, build, packaging, and isolated
tests from a fresh checkout. The bootstrap's revision checks protect reproducibility.

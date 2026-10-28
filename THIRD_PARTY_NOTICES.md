# Third-party notices

The MIT license in this repository applies to its original contributions. It
does not grant rights to the original game, upstream program, patch context,
or separately licensed third-party code.

## Original game

Need for Speed II Special Edition is commercial software. Its game data, original
executables, names, artwork, tracks, models, music, and other content remain the
property of their respective rights holders. No such files are distributed in
this repository. Supply your own game data for local use. Locally built app
bundles include that data and are not published here.

## motor-dev/nfs-recompiled

Source: <https://github.com/motor-dev/nfs-recompiled>

Pinned commit: `77ebdb3b6a21925ccfc4fc4c1d712abec3e1945a`.

The full upstream tree is fetched locally, not mirrored here. No standalone
top-level license file was present in the tested checkout; this repository does
not assign a new license to upstream code or the original translated program.
The patch includes small upstream context fragments to identify changes. Consult
upstream terms and original rights before redistributing a modified runtime.

## zaps166/NFSIISEN

Source: <https://github.com/zaps166/NFSIISEN>

Pinned commit: `ad73d45c7f2f5f8c384c8b46dd9c82125578e647`.

Fetched locally for companion installation metadata. Neither its game files nor
its Windows patch executable are republished in this repository. Its Windows
program is not executed by these scripts.

## SSE2NEON

Source: <https://github.com/DLTcollab/sse2neon>

Pinned commit: `2272251cc3ad9cba8b8c47c4065811cfb396b802`.

The unmodified header is distributed under its MIT license. The full notice is
retained in `port/include/third_party/sse2neon.LICENSE` and in the header itself.
Provenance is recorded alongside it.

## SDL3

Source: <https://github.com/libsdl-org/SDL>

SDL3 is a build dependency under the zlib license. It is not vendored here. The
local packaging script copies the installed library and its license into the app.

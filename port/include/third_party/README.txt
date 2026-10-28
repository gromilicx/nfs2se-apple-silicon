sse2neon.h

Upstream: https://github.com/DLTcollab/sse2neon
Pinned commit: 2272251cc3ad9cba8b8c47c4065811cfb396b802
Retrieved: 2026-10-28
Source: https://raw.githubusercontent.com/DLTcollab/sse2neon/2272251cc3ad9cba8b8c47c4065811cfb396b802/sse2neon.h
License: MIT (sse2neon.LICENSE; also embedded in the header)

The vendored header is unmodified. On Arm64 it translates the SSE2 operations
used to express the original game's MMX instructions into native NEON
instructions. On x86 the project continues to use immintrin.h.

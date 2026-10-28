# Contributing

Use the pinned upstream revisions and keep the public repository limited to port
changes, tooling, tests, and documentation. Do not submit commercial game assets,
installers, executable files, extracted data, saves, or data-bearing app bundles.

1. Run `scripts/setup-source.sh` and build according to the README.
2. Make changes to the prepared checkout as needed.
3. Export changes to tracked upstream files into `patches/apple-silicon.patch`.
   Keep newly added port files in the corresponding paths under `port/`.
4. Check that the patch and overlay can prepare a fresh upstream checkout.
5. Build, run the relevant isolated tests, and describe any gameplay checks and
   their limits. Do not claim effects were visually tested when only flags were checked.

Scripts must preserve user saves and avoid silently overwriting modified source.
Keep Cocoa/SDL graphics work on the main thread and guest-memory operations on
the correct game thread. Treat changes to these boundaries as functional changes.

Keep documentation in English. The current panel's Serbian labels are translated
in the README; a future localization change should preserve keyboard navigation,
native accessibility, and clear disabled/active states.

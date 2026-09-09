# ADR 0002: Block openemu.org core downloads when running natively on arm64

**Status:** Accepted — 2026-09-08

## Context

OpenEmu offers emulator cores for download from `OECoreListURL`
(openemu.org's `oecores.xml`) — at first launch (Setup Assistant), in
Preferences ▸ Cores, and when a game or save state needs a core that is not
installed. Installed cores are also checked for updates against their appcasts,
and updates are installed automatically at launch.

Those downloads are built for Intel Macs only. A native arm64 process cannot load
an x86_64-only plug-in, so on Apple silicon every such download fails silently at
load time and leaves a broken core behind. Under Rosetta the x86_64 slice of
OpenEmu runs and those cores work.

## Decision

- `CoreUpdater.coreDownloadsBlocked` is decided per executing slice with
  `#if arch(arm64)`: true in the arm64 slice, false in the x86_64 slice. No
  runtime detection is needed — the slice that is running is the fact that
  matters.
- When blocked, `checkForNewCores` and `checkForUpdates` are no-ops that complete
  without error, so the Setup Assistant and Preferences carry on showing only the
  installed cores and no Intel-only core is ever offered; automatic updates at
  launch are skipped with a log line.
- The user-initiated install entries (`installCore(for:)` for games and save
  states, `installCore(with:)`, `installCoreInBackgroundUserInitiated`) present a
  single `OEAlert` — "Core Downloads Unavailable" — explaining the reason and
  where to put Apple silicon cores, then return `NSUserCancelledError`, which
  every caller already treats as a silent cancel.

## Consequences

- On Apple silicon, cores come from the release's `cores/` folder or from manual
  installation into `~/Library/Application Support/OpenEmu/Cores`.
- Running OpenEmu under Rosetta restores the upstream download behaviour
  unchanged.
- If a fork-specific core feed with universal builds appears later, the gate is
  a single property to relax, and `OECoreListURL` the place to point elsewhere.

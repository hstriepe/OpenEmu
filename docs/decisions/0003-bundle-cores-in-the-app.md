# ADR 0003: Bundle the cores inside OpenEmu.app

**Status:** Accepted — 2026-09-08

## Context

Upstream OpenEmu ships without cores and downloads them from openemu.org on
demand. This fork blocks those downloads on Apple silicon (ADR 0002) because
they are Intel-only, so a user of the native arm64 build had to copy cores
from the release's `cores/` folder into `~/Library/Application Support/OpenEmu/Cores`
by hand. Separately, core plug-ins cannot carry a stapled notarization ticket
(ADR 0001), so loose cores are validated by Gatekeeper online only.

`OEPlugin.plugins()` already scans two locations: App Support first (with
`forceReload`), then `OpenEmu.app/Contents/PlugIns/Cores`, skipping any name it
has already loaded.

## Decision

The release script bundles every validated core into
`OpenEmu.app/Contents/PlugIns/Cores` by default (`--no-bundle-cores` opts out),
signs each with the release identity, re-seals the app once, and then notarizes.
`release/cores/` is still produced for manual installation.

Shipped copies — bundled and in `release/cores/` alike — are stamped
`<emulator version with its last component incremented>.<OpenEmu build>`, e.g.
Nestopia `1.52` → `1.53.7428`, GenesisPlus `1.7.5.1` → `1.7.5.2.7428`. Cores only
carry `CFBundleVersion`, which Preferences ▸ Cores displays and the update
comparator reads, so the stamp marks them as this fork's builds, sorts them above
upstream's version, and names the OpenEmu build they shipped with. The sources in
App Support keep the emulator's own version.

## Consequences

- The app is self-contained; no download is triggered and no manual install is
  needed. App size grows from ~78 MB to ~185 MB with the current 19 cores.
- A copy of the same core in App Support **overrides** the bundled one, so
  user-added or newer cores keep working exactly as before.
- Bundled cores are nested code of the app and are covered by the app's
  stapled ticket — offline Gatekeeper validation, which loose plug-ins cannot get.
  The per-binary release gate grows from 47 to 66 Mach-Os.
- A core update means an app release. Under Rosetta, an upstream update
  installs into App Support and takes precedence, as before.
- The loader deletes out-of-support plug-ins on sight, which inside a sealed
  app would break its signature. None of the bundled cores can trip that rule:
  none is in the deprecated-name list, none uses a beta-era `openemu.org/update`
  feed, none carries deprecation markers, and all declare `CFBundleIdentifier`.
  `collect_cores` in the release script should gain that check if the core set
  ever changes.
- Only cores with an arm64 slice are shipped. A core in App Support without one
  (an old x86_64-only build, say) cannot load in the arm64 slice that ADR 0002
  assumes, so `collect_cores` leaves it out with a warning and the run summary
  lists it, rather than bundling dead weight into the app. Under Rosetta a user
  can still install such a core into App Support by hand.
- Xcode development builds are unaffected; only the release script bundles.

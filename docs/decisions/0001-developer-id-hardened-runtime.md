# ADR 0001: Developer ID distribution with hardened runtime

**Status:** Accepted — 2026-09-07

## Context

Notarizing a release build on 2026-09-05 was rejected by Apple (submission
`d018462b-…`, status *Invalid*). Every executable was flagged for the same four
reasons: signed with an *Apple Development* certificate, no secure timestamp,
hardened runtime disabled, and the debug `get-task-allow` entitlement present.

Two targets (`OpenEmuHelperApp`, `OESaveStateQLPlugin`) hard-code ad-hoc signing
in the project, so they ignore `CodeSign.xcconfig`. Re-signing the finished app with
`codesign --deep` cannot fix this correctly: it applies one set of entitlements to
every nested binary and strips the QuickLook extensions' sandbox entitlements.

Enabling hardened runtime introduces a second problem: OpenEmu loads core plugins
from `~/Library/Application Support/OpenEmu/Cores` that are built and signed
separately (currently ad-hoc, `TeamIdentifier=not set`), and several cores use
dynamic recompilers. Library validation would refuse to load them, and JIT cores
would crash.

## Decision

1. **Distribution signing is applied as `xcodebuild` overrides** in
   `bin/release-build.sh`, not in the project: `CODE_SIGN_STYLE=Manual`,
   `CODE_SIGN_IDENTITY="Developer ID Application"`, `DEVELOPMENT_TEAM`,
   `ENABLE_HARDENED_RUNTIME=YES`, `OTHER_CODE_SIGN_FLAGS=--timestamp`,
   `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`. Command-line settings outrank every
   target-level setting, so the hard-coded ad-hoc targets are covered, and
   day-to-day Xcode builds keep using the developer certificate.

2. **Runtime entitlements live in the project**, per target:
   - `OpenEmu/OpenEmu.entitlements` — `cs.disable-library-validation`
   - `OpenEmu/OpenEmuHelperApp/OpenEmuHelperApp.entitlements` —
     `cs.disable-library-validation`, `cs.allow-jit`,
     `cs.allow-unsigned-executable-memory`
   These are harmless in Debug and required in Release.

3. **The release script verifies before it notarizes**: every Mach-O inside the
   bundle (app, helper, frameworks, XPC services, app extensions, QuickLook
   generator, system plugins) must carry the Developer ID authority, the team,
   the `runtime` flag, and a timestamp, and must not request `get-task-allow`;
   the app and helper must carry the entitlements above. A failed check aborts
   before any upload. Conditional settings (`SETTING[sdk=…]`) are not accepted
   on the `xcodebuild` command line; the unconditional override is sufficient.

4. **Sparkle's nested executables are re-signed after the build.** The SPM binary
   XCFramework (2.5.2) ships `Autoupdate`, `Updater.app`, `Installer.xpc`, and
   `Downloader.xpc` ad-hoc signed, and Xcode's Code Sign On Copy re-signs only the
   outer framework. The script signs them inside-out with
   `--preserve-metadata=entitlements` (Downloader.xpc is sandboxed), then re-seals
   `Sparkle.framework` and `OpenEmu.app`. This is the procedure Sparkle documents.

5. **Cores are re-signed** with the release identity when copied into
   `release/cores`, so the whole distribution carries one Team ID. Notarizing
   cores individually is available (`--notarize-cores`) but opt-in.

## Consequences

- Notarization requirements are met without touching `CodeSignDefault.xcconfig`
  or the per-developer `CodeSign.xcconfig`.
- `disable-library-validation` weakens hardened runtime by design; this matches
  upstream OpenEmu, which must load third-party cores.
- `ntmy --submit` exits 0 even when stapling fails, so the script validates the
  stapled ticket and asks Gatekeeper (`spctl`) explicitly.
- Sparkle's `SUFeedURL`/`SUPublicEDKey` still point at upstream OpenEmu; Sparkle 2
  rejects updates signed by a different team, so auto-update is effectively inert
  for this fork until a feed for this Team ID exists.

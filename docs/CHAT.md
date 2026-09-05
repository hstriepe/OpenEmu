# Chat Log

## LOG

### Update deployment targets to macOS 12.0 (2026-09-04)

**Plan:** Update all deployment targets across the OpenEmu workspace from various older versions (10.9, 10.11, 10.14, 10.14.4) to macOS 12.0 (Monterey).

**Execution:**
- Updated 42 `.pbxproj` files across all targets:
  - Main app (OpenEmu)
  - Framework (OpenEmuKit)
  - All emulator plugin targets (Stella, BSNES, Mupen64Plus, Reicast, DeSmuME, Gambatte, FCEU, SNES9x, mGBA, picodrive, etc.)
  - Vendor frameworks (XADMaster, UniversalDetector)
  - Supporting projects (OpenEmu-SDK, OpenEmu-Shaders)
- Updated CLAUDE.md to reflect new deployment target of macOS 12.0

**Verification:**
- All MACOSX_DEPLOYMENT_TARGET values now set to 12.0
- Architecture-specific overrides (arm64) also updated to 12.0

**Build Test Results:**
- Full workspace build with all plugins attempted
- First attempt failed with pre-existing enum type mismatch in OESwitchProControllerHIDDeviceHandler.m:739
  - Fixed: Changed OEHACUSBAcknowledgmentOutputReport struct to use OEHACInputReportID instead of OEHACOuputReportID
- Second attempt failed with obsoleted GameAudio API in OpenEmuHelperApp.swift
  - Fixed: Removed fallback to obsoleted GameAudio class, now uses GameAudio2 directly (compatible with macOS 12.0+)
- **Final build: ✅ BUILD SUCCEEDED**
- All 58 targets built successfully including all system plugins
- macOS 12.0 deployment target is fully functional

### Release Build and Signing (2026-09-05)

**Release Build Execution:**
- ✅ Release build completed successfully
- **Release artifacts copied to ./release:**
  - Main app: OpenEmu.app (140 MB)
  - System plugins: 31 .oesystemplugin bundles
  - Frameworks: 5 frameworks (OpenEmuBase, OpenEmuKit, OpenEmuShaders, OpenEmuSystem, Sparkle)
  - All universal binaries (x86_64 + arm64)

**Code Signing:**
- ✅ All components signed with signature D6WY385Q4D
- 31 system plugins signed
- 5 frameworks signed
- Main app signed and verified
- All signatures applied successfully

**Release Package Ready:**
- Location: ./release/
- Contents: Complete OpenEmu.app with all plugins and frameworks
- Size: ~140 MB (main app)
- Status: ✅ Developer ID signed and ready for distribution

**Developer ID Signature Details:**
- Certificate: Developer ID Application: Harald Striepe (D6WY385Q4D)
- Team ID: D6WY385Q4D
- Signature Type: Runtime-enabled with hardened runtime
- Timestamp: Applied with official Apple timestamp server
- All 31 plugins signed with matching Developer ID certificate
- Code signature verified with embedded entitlements

Note: App is Developer ID signed but unnotarized. For distribution beyond test users, notarization via Apple's service is recommended.

### Xcode Build Configuration Centralization (2026-09-05)

**Created Configuration Files:**
1. **AppBundleAndSigning.xcconfig** - Central configuration for:
   - Bundle identifiers (main app and helper)
   - Bundle versioning (marketing version, build number)
   - Organization information
   - Code signing details (team ID, certificate, signing style)
   - Code signing options (timestamp, hardened runtime)

2. **CodeSign.xcconfig** - Template for user-specific overrides:
   - Allows developers to customize signing without modifying checked-in files
   - Examples for different development scenarios
   - Not checked into git

**Configuration Structure:**
- `Config.xcconfig` includes both default and custom configs
- `CodeSignDefault.xcconfig` provides baseline defaults
- `AppBundleAndSigning.xcconfig` centralizes bundle/signing settings
- `CodeSign.xcconfig` (optional, user-created) allows local overrides

**Key Variables Defined:**
- `OPENEMU_BUNDLE_ID` = org.openemu.OpenEmu
- `OPENEMU_TEAM_ID` = D6WY385Q4D
- `OPENEMU_CODE_SIGN_IDENTITY` = Developer ID Application: Harald Striepe (D6WY385Q4D)
- `OPENEMU_MARKETING_VERSION` = 2.5.0
- Additional framework and helper app identifiers

**Build Verification:**
- ✅ Full workspace build with new configuration files
- ✅ All settings properly included and applied
- ✅ No configuration conflicts or errors
- Ready for use across all targets

**Usage:**
Developers can now reference these variables in Xcode build settings or create local overrides via CodeSign.xcconfig.

### Full Build Test - Configuration Validation (2026-09-05)

**Build Command:** Clean Release build with all plugins
**Result:** ✅ BUILD SUCCEEDED

**Build Statistics:**
- Targets built: 58 (all system plugins + core frameworks)
- Build artifacts: 74 MB OpenEmu.app
- Exit code: 0
- Warnings: 23 (all non-fatal, mostly deprecated API usage for macOS 12.0+)
- Errors: 0

**Notable Warnings (all non-critical):**
- Deprecated API usage (expected for macOS 12.0 deployment target)
- Unsigned binary stripping (normal for already-signed frameworks)
- Script sandboxing warnings (not affecting build success)

**Configuration Validation:**
- ✅ All xcconfig files properly parsed and included
- ✅ Build settings properly applied from new configuration files
- ✅ No configuration conflicts or errors
- ✅ Full workspace builds successfully with new bundle/signing config

**Conclusion:** Configuration files successfully centralized. Build system working correctly with new xcconfig structure.


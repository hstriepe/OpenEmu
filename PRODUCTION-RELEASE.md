# OpenEmu Production Release v2.5.0 (Build 7414)
## ✅ NOTARIZED & READY FOR DISTRIBUTION

### Release Status
**PRODUCTION READY** - Fully notarized and approved by Apple

### Version Information
- **Version:** 2.5.0
- **Build Number:** 7414
- **Release Date:** 2026-09-05
- **Status:** Notarized & Stapled
- **Distribution:** Ready for immediate deployment

### What's Notarized
- ✅ OpenEmu.app (142 MB) - Universal binary
- ✅ All 31 emulator cores
- ✅ All 5 frameworks
- ✅ Developer ID: Harald Striepe (D6WY385Q4D)
- ✅ Notarization ticket: STAPLED

### System Requirements
- macOS 12.0 (Monterey) or later
- Intel or Apple Silicon Mac
- 500 MB free disk space

### Key Improvements
- macOS 12.0+ deployment target
- Full universal binary support (x86_64 + arm64)
- Dolphin GameCube/Wii emulation with macOS 2024+ fixes
- Developer ID signed with hardened runtime
- Notarized - no Gatekeeper warnings on download

### Distribution Methods

#### Direct Download
```bash
# Extract and install
tar -xzf OpenEmu-2.5.0-build7414.tar.gz
cp -r OpenEmu.app /Applications/
```

#### From Release Directory
```bash
cp -r release/OpenEmu.app /Applications/
/Applications/OpenEmu.app/Contents/MacOS/OpenEmu
```

### Verification

Check notarization status:
```bash
spctl -a -vvv /Applications/OpenEmu.app
# Should show: accepted
```

### Package Contents
- **OpenEmu.app** - Main application (notarized)
- **31 Emulator Cores** - All major gaming systems
- **5 Frameworks** - Supporting libraries
- **BuildMacOSUniversalBinary.py** - Universal build script

### Included Emulator Systems
NES, SNES, Genesis, N64, PlayStation, GameCube (Dolphin), 
Game Boy, Game Boy Advance, Nintendo DS, Arcade systems, 
and many more classic gaming platforms.

### Technical Details

**Code Signing**
- Certificate: Developer ID Application: Harald Striepe
- Team ID: D6WY385Q4D
- Signature Type: Developer ID (runtime-enabled)
- Hardened Runtime: Enabled

**Notarization**
- Submitted: 2026-09-05
- Status: Approved ✅
- Ticket: Stapled to app ✅
- Ready for distribution: Yes ✅

**Architecture Support**
- x86_64 (Intel Mac)
- arm64 (Apple Silicon)
- Universal binary (both architectures in one file)

### Dolphin-Core Compatibility
- BuildMacOSUniversalBinary.py included
- Cross-compilation support for arm64 and x86_64
- macOS 2024+ compatibility verified
- No crashing issues on recent macOS versions

### Next Steps

1. **Direct Distribution**
   - Share the notarized app or archive
   - Users can download and install without Gatekeeper warnings

2. **App Store (Optional)**
   - Submit to Mac App Store for broader distribution
   - Notarization is a prerequisite

3. **Website Distribution**
   - Host the 99 MB archive
   - Distribute via download link
   - Automatic update support via Sparkle framework

### Support
For issues or questions:
- Documentation: EXPERIMENTAL-RELEASE.md
- Build System: RELEASE-BUILD.md
- Project Guidelines: CLAUDE.md
- GitHub: https://github.com/hstriepe/OpenEmu

---

**This release is fully production-ready and can be distributed
immediately to end users without any additional steps.**

#!/bin/bash
# OpenEmu Release Build Script
# Builds, signs (Developer ID + hardened runtime + secure timestamp), verifies,
# notarizes, and organizes OpenEmu release artifacts.
#
# Usage: bin/release-build.sh [options]
# Options:
#   --metal           Build OpenEmu-metal.xcworkspace ("OpenEmu + Stella") into ./release-metal
#   --notarize        Notarize and staple OpenEmu.app (requires ~/bin/ntmy + keychain profile)
#   --notarize-cores  Also notarize and staple every core plugin (one submission per core; slow)
#   --skip-build      Reuse existing build products (still verifies, notarizes, organizes)
#   --help            Show this help
#
# Signing is applied as xcodebuild overrides so everyday Xcode builds keep using
# CodeSign.xcconfig (Apple Development). Runtime entitlements come from the project:
#   OpenEmu/OpenEmu.entitlements
#   OpenEmu/OpenEmuHelperApp/OpenEmuHelperApp.entitlements
#
# Cores are taken from ~/Library/Application Support/OpenEmu/Cores, where every
# core's "Build & Install" target installs, then re-signed with the release identity.
#
# Environment overrides: OPENEMU_TEAM_ID, OPENEMU_SIGNING_IDENTITY, OPENEMU_NOTARIZE_TOOL

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CONFIGURATION="Release"
TEAM_ID="${OPENEMU_TEAM_ID:-D6WY385Q4D}"
SIGNING_IDENTITY="${OPENEMU_SIGNING_IDENTITY:-Developer ID Application}"
NOTARIZATION_TOOL="${OPENEMU_NOTARIZE_TOOL:-$HOME/bin/ntmy}"
APP_SUPPORT_CORES="$HOME/Library/Application Support/OpenEmu/Cores"
LOG_DIR="$REPO_DIR/build"

VARIANT="standard"
WORKSPACE="$REPO_DIR/OpenEmu.xcworkspace"
SCHEME="OpenEmu"
RELEASE_DIR="$REPO_DIR/release"
CORES=()            # empty = every core installed in App Support
ENABLE_NOTARIZE=0
NOTARIZE_CORES=0
SKIP_BUILD=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --metal)
            VARIANT="metal"
            WORKSPACE="$REPO_DIR/OpenEmu-metal.xcworkspace"
            SCHEME="OpenEmu + Stella"
            RELEASE_DIR="$REPO_DIR/release-metal"
            CORES=(Stella SNES9x)
            ;;
        --notarize)       ENABLE_NOTARIZE=1 ;;
        --notarize-cores) ENABLE_NOTARIZE=1; NOTARIZE_CORES=1 ;;
        --skip-build)     SKIP_BUILD=1 ;;
        --help)
            grep "^#" "$0" | grep -v "^#!" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

CORES_DIR="$RELEASE_DIR/cores"
FRAMEWORKS_DIR="$RELEASE_DIR/Frameworks"
BUILD_LOG="$LOG_DIR/release-build-$VARIANT.log"

# Everything Apple's notary service checks, applied to every target in the build.
SIGN_SETTINGS=(
    "CODE_SIGN_STYLE=Manual"
    "CODE_SIGN_IDENTITY=$SIGNING_IDENTITY"
    "DEVELOPMENT_TEAM=$TEAM_ID"
    "PROVISIONING_PROFILE_SPECIFIER="
    "ENABLE_HARDENED_RUNTIME=YES"
    "OTHER_CODE_SIGN_FLAGS=--timestamp"
    "CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO"
)

log()     { echo "[$(date +'%H:%M:%S')] $*"; }
success() { echo "✅ $*"; }
error()   { echo "❌ ERROR: $*" >&2; exit 1; }

# codesign(1) needs the full certificate name; Xcode resolves the generic one itself.
resolve_codesign_identity() {
    security find-identity -v -p codesigning \
        | grep "$SIGNING_IDENTITY" | grep "($TEAM_ID)" | head -1 \
        | sed -E 's/.*"(.*)"/\1/'
}

verify_prerequisites() {
    log "Verifying prerequisites..."
    [ -f "$WORKSPACE/contents.xcworkspacedata" ] || error "Workspace not found: $WORKSPACE"
    CODESIGN_IDENTITY="$(resolve_codesign_identity)"
    [ -n "$CODESIGN_IDENTITY" ] || error "No '$SIGNING_IDENTITY' certificate for team $TEAM_ID in keychain"
    if [ $ENABLE_NOTARIZE -eq 1 ]; then
        [ -x "$NOTARIZATION_TOOL" ] || error "Notarization tool not found: $NOTARIZATION_TOOL"
    fi
    mkdir -p "$LOG_DIR"
    success "Prerequisites verified (signing as: $CODESIGN_IDENTITY)"
}

resolve_build_dir() {
    BUILD_DIR="$(xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
        -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR /{print $2; exit}')"
    [ -n "$BUILD_DIR" ] || error "Could not resolve BUILT_PRODUCTS_DIR for scheme '$SCHEME'"
    APP="$BUILD_DIR/OpenEmu.app"
    HELPER="$APP/Contents/Resources/OpenEmuHelperApp"
    log "Build products: $BUILD_DIR"
}

build_workspace() {
    log "Building '$SCHEME' ($CONFIGURATION) with Developer ID + hardened runtime..."
    log "Full log: $BUILD_LOG"
    if ! xcodebuild -workspace "$WORKSPACE" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
            clean build "${SIGN_SETTINGS[@]}" >"$BUILD_LOG" 2>&1; then
        grep -E "error:|\*\* BUILD" "$BUILD_LOG" | tail -20 >&2
        error "Build failed (see $BUILD_LOG)"
    fi
    success "Build completed"
}

# Sparkle ships as a pre-built XCFramework whose nested executables are ad-hoc signed,
# and Xcode's "Code Sign On Copy" only re-signs the outer framework. The notary
# service rejects ad-hoc code, so sign the nested items inside-out, then re-seal the
# framework and the app. Downloader.xpc carries a sandbox entitlement that must
# survive, hence --preserve-metadata=entitlements. (Sparkle docs: Code signing.)
resign_sparkle() {
    local fw="$APP/Contents/Frameworks/Sparkle.framework"
    [ -d "$fw" ] || return 0
    log "Re-signing Sparkle's nested executables with team $TEAM_ID..."
    local v; v="$(cd "$fw/Versions/Current" && pwd -P)"
    local item out
    for item in "$v/XPCServices/Installer.xpc" "$v/XPCServices/Downloader.xpc" \
                "$v/Autoupdate" "$v/Updater.app" "$fw"; do
        [ -e "$item" ] || continue
        out="$(codesign --force --sign "$CODESIGN_IDENTITY" --options runtime --timestamp \
                --preserve-metadata=entitlements "$item" 2>&1)" \
            || error "Failed to re-sign ${item#"$APP"/}: $out"
    done
    # The framework's seal changed, so the app's seal must be regenerated as well.
    out="$(codesign --force --sign "$CODESIGN_IDENTITY" --options runtime --timestamp \
            --preserve-metadata=entitlements "$APP" 2>&1)" \
        || error "Failed to re-seal OpenEmu.app: $out"
    success "Sparkle nested code re-signed; OpenEmu.app re-sealed"
}

# The four things the notary service rejected on 2026-09-05, checked per Mach-O.
check_notary_requirements() {
    local bin=$1 name; name="${bin#"$APP"/}"
    local info; info="$(codesign -dvv "$bin" 2>&1)"
    grep -q "Authority=$SIGNING_IDENTITY" <<<"$info" || error "$name: not signed with '$SIGNING_IDENTITY'"
    grep -q "TeamIdentifier=$TEAM_ID"     <<<"$info" || error "$name: TeamIdentifier is not $TEAM_ID"
    grep -q "flags=.*runtime"             <<<"$info" || error "$name: hardened runtime not enabled"
    grep -q "^Timestamp="                 <<<"$info" || error "$name: no secure timestamp"
    if codesign -d --entitlements - "$bin" 2>/dev/null | grep -q "get-task-allow"; then
        error "$name: get-task-allow entitlement present"
    fi
}

# What OpenEmu needs at runtime once hardened runtime is on.
check_runtime_entitlements() {
    local bin=$1 name; name="${bin#"$APP"/}"; shift
    local ents; ents="$(codesign -d --entitlements - "$bin" 2>/dev/null || true)"
    local key
    for key in "$@"; do
        grep -q "$key" <<<"$ents" || error "$name: missing entitlement $key"
    done
}

verify_signing() {
    log "Verifying signatures, hardened runtime, and entitlements..."
    [ -d "$APP" ] || error "App not found: $APP"
    codesign --verify --deep --strict "$APP" || error "codesign --verify failed for OpenEmu.app"

    local count=0 f
    while IFS= read -r -d '' f; do
        file -b "$f" | grep -q "Mach-O" || continue
        check_notary_requirements "$f"
        count=$((count + 1))
    done < <(find "$APP" -type f -perm -u+x -print0)
    [ $count -gt 0 ] || error "No Mach-O binaries found in $APP"

    check_runtime_entitlements "$APP"    com.apple.security.cs.disable-library-validation
    check_runtime_entitlements "$HELPER" com.apple.security.cs.disable-library-validation \
                                         com.apple.security.cs.allow-jit \
                                         com.apple.security.cs.allow-unsigned-executable-memory
    success "$count Mach-O binaries: Developer ID, hardened runtime, timestamped, no get-task-allow; entitlements present"
}

notarize_app() {
    log "Notarizing OpenEmu.app (waits for Apple)..."
    # ntmy exits 0 even when stapling fails, so validate explicitly afterwards.
    "$NOTARIZATION_TOOL" --submit "$APP" || error "Notarization failed — inspect with: $NOTARIZATION_TOOL --log"
    xcrun stapler validate "$APP" || error "No valid stapled ticket — notarization was rejected; run: $NOTARIZATION_TOOL --log"
    local verdict; verdict="$(spctl -a -vv -t exec "$APP" 2>&1)"
    grep -q "source=Notarized Developer ID" <<<"$verdict" || error "Gatekeeper rejected app: $verdict"
    success "OpenEmu.app notarized, stapled, and accepted by Gatekeeper"
}

organize_release() {
    log "Organizing release into $RELEASE_DIR..."
    rm -rf "$RELEASE_DIR"
    mkdir -p "$CORES_DIR" "$FRAMEWORKS_DIR"

    ditto "$APP" "$RELEASE_DIR/OpenEmu.app"

    local fw
    for fw in "$APP"/Contents/Frameworks/*.framework; do
        ditto "$fw" "$FRAMEWORKS_DIR/$(basename "$fw")"
    done

    local sources=() c
    if [ ${#CORES[@]} -eq 0 ]; then
        for c in "$APP_SUPPORT_CORES"/*.oecoreplugin; do
            [ -d "$c" ] && sources+=("$c")
        done
    else
        local name
        for name in "${CORES[@]}"; do
            c="$APP_SUPPORT_CORES/$name.oecoreplugin"
            [ -d "$c" ] || error "Core not installed: $c (run its 'Build & Install' target first)"
            sources+=("$c")
        done
    fi
    [ ${#sources[@]} -gt 0 ] || error "No cores found in $APP_SUPPORT_CORES"

    local src dst
    for src in "${sources[@]}"; do
        dst="$CORES_DIR/$(basename "$src")"
        ditto "$src" "$dst"
        codesign --force --deep --sign "$CODESIGN_IDENTITY" --timestamp --options runtime "$dst" >/dev/null 2>&1 \
            || error "Failed to sign $(basename "$dst")"
        codesign --verify --deep --strict "$dst" || error "Signature verification failed: $(basename "$dst")"
        if [ $NOTARIZE_CORES -eq 1 ]; then
            "$NOTARIZATION_TOOL" --submit "$dst" || true
            xcrun stapler validate "$dst" || error "Core notarization failed: $(basename "$dst")"
        fi
        log "  core: $(basename "$dst")"
    done
    success "Release organized"
}

print_summary() {
    local plist="$RELEASE_DIR/OpenEmu.app/Contents/Info.plist"
    local ver build
    ver="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"
    build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist")"
    echo
    log "=========================================="
    log "Release Build Complete — $VARIANT"
    log "=========================================="
    log "Version:    $ver ($build)"
    log "Location:   $RELEASE_DIR"
    log "App:        OpenEmu.app ($(du -sh "$RELEASE_DIR/OpenEmu.app" | cut -f1))"
    log "Cores:      $(find "$CORES_DIR" -maxdepth 1 -name '*.oecoreplugin' | wc -l | tr -d ' ')"
    log "Frameworks: $(find "$FRAMEWORKS_DIR" -maxdepth 1 -name '*.framework' | wc -l | tr -d ' ')"
    log "Identity:   $CODESIGN_IDENTITY"
    log "Notarized:  $([ $ENABLE_NOTARIZE -eq 1 ] && echo Yes || echo No)"
    log "=========================================="
}

main() {
    log "OpenEmu Release Build — variant: $VARIANT, scheme: '$SCHEME'"
    verify_prerequisites
    resolve_build_dir
    if [ $SKIP_BUILD -eq 0 ]; then
        build_workspace
    else
        log "Skipping build (using existing products in $BUILD_DIR)"
    fi
    resign_sparkle
    verify_signing
    if [ $ENABLE_NOTARIZE -eq 1 ]; then
        notarize_app
    else
        log "Notarization disabled (use --notarize)"
    fi
    organize_release
    print_summary
}

main "$@"

#!/bin/bash
# OpenEmu Release Build Script with Notarization
# This script builds, signs, notarizes, and organizes OpenEmu for release
#
# Usage: ./release-build.sh [options]
# Options:
#   --notarize    Enable notarization (requires ~/bin/ntmy)
#   --skip-build  Use existing build artifacts
#   --help        Show this help message

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${SCRIPT_DIR}/OpenEmu.xcworkspace"
SCHEME="OpenEmu"
CONFIGURATION="Release"
EXPERIMENTAL=0
RELEASE_DIR="${SCRIPT_DIR}/release"
CORES_DIR="${RELEASE_DIR}/cores"
FRAMEWORKS_DIR="${RELEASE_DIR}/Frameworks"

# Build artifacts location - dynamically discover based on workspace
DERIVED_DATA="${HOME}/Library/Developer/Xcode/DerivedData"
if [ $EXPERIMENTAL -eq 1 ]; then
    BUILD_DIR=$(find "$DERIVED_DATA" -name "OpenEmu-experimental-*" -type d 2>/dev/null | head -1)/Build/Products/${CONFIGURATION}
else
    BUILD_DIR=$(find "$DERIVED_DATA" -name "OpenEmu-eegmifgmujisblbtyrbawrwlgbeh" -type d 2>/dev/null | head -1)/Build/Products/${CONFIGURATION}
    [ -z "$BUILD_DIR" ] && BUILD_DIR=$(find "$DERIVED_DATA" -name "OpenEmu-*" -type d 2>/dev/null | grep -v experimental | head -1)/Build/Products/${CONFIGURATION}
fi

# Configuration values from xcconfig
TEAM_ID="${OPENEMU_TEAM_ID:-D6WY385Q4D}"
SIGNING_CERT="${OPENEMU_CODE_SIGN_IDENTITY:-Developer ID Application: Harald Striepe (D6WY385Q4D)}"
NOTARIZATION_TOOL="${HOME}/bin/ntmy"

# Parse arguments
ENABLE_NOTARIZE=0
SKIP_BUILD=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --notarize) ENABLE_NOTARIZE=1; shift ;;
        --skip-build) SKIP_BUILD=1; shift ;;
        --experimental) EXPERIMENTAL=1; WORKSPACE="${SCRIPT_DIR}/OpenEmu-experimental.xcworkspace"; SCHEME="OpenEmu + Cores (Experimental, Alpha)"; shift ;;
        --help)
            grep "^#" "$0" | grep -v "^#!/bin/bash" | sed 's/^# //'
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Functions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "❌ ERROR: $*" >&2
    exit 1
}

success() {
    echo "✅ $*"
}

# Verify prerequisites
verify_prerequisites() {
    log "Verifying prerequisites..."

    if [ ! -f "$WORKSPACE/contents.xcworkspacedata" ]; then
        error "Workspace not found: $WORKSPACE"
    fi

    if [ $ENABLE_NOTARIZE -eq 1 ] && [ ! -f "$NOTARIZATION_TOOL" ]; then
        error "Notarization tool not found: $NOTARIZATION_TOOL"
    fi

    success "Prerequisites verified"
}

# Build the workspace
build_workspace() {
    log "Building OpenEmu with Release configuration..."

    cd "$SCRIPT_DIR"

    xcodebuild -workspace "$WORKSPACE" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        clean build || error "Build failed"

    success "Build completed"
}

# Sign the app
sign_app() {
    local app_path="$BUILD_DIR/OpenEmu.app"

    log "Signing app: $app_path"

    if [ ! -d "$app_path" ]; then
        error "App not found: $app_path"
    fi

    # Use codesign to ensure proper team ID
    codesign -s "$SIGNING_CERT" -fv --deep --options=runtime --timestamp "$app_path" 2>&1 | tail -3

    success "App signed with Team ID: $TEAM_ID"
}

# Notarize the app
notarize_app() {
    local app_path="$BUILD_DIR/OpenEmu.app"

    log "Notarizing app..."

    if [ ! -f "$NOTARIZATION_TOOL" ]; then
        error "Notarization tool not available: $NOTARIZATION_TOOL"
    fi

    # Use the notarization tool to submit and staple
    "$NOTARIZATION_TOOL" --submit "$app_path" || error "Notarization failed"

    success "App notarized and stapled"
}

# Organize release artifacts
organize_release() {
    log "Organizing release artifacts..."

    # Clean and create directories
    rm -rf "$RELEASE_DIR"
    mkdir -p "$CORES_DIR" "$FRAMEWORKS_DIR"

    # Copy main app
    log "Copying OpenEmu.app..."
    cp -r "$BUILD_DIR/OpenEmu.app" "$RELEASE_DIR/"

    # Copy plugin cores
    log "Copying plugin cores..."
    find "$BUILD_DIR" -maxdepth 1 -name "*.oesystemplugin" -type d | while read plugin; do
        cp -r "$plugin" "$CORES_DIR/"
        log "  Copied: $(basename "$plugin")"
    done

    # Copy frameworks
    log "Copying frameworks..."
    for framework in OpenEmuBase OpenEmuKit OpenEmuShaders OpenEmuSystem Sparkle; do
        if [ -d "$BUILD_DIR/${framework}.framework" ]; then
            cp -r "$BUILD_DIR/${framework}.framework" "$FRAMEWORKS_DIR/"
            log "  Copied: ${framework}.framework"
        fi
    done

    success "Artifacts organized in $RELEASE_DIR"
}

# Print summary
print_summary() {
    log "=========================================="
    log "Release Build Complete"
    log "=========================================="
    log "Location: $RELEASE_DIR"
    log "App: OpenEmu.app ($(du -sh "$RELEASE_DIR/OpenEmu.app" | cut -f1))"
    log "Plugins: $(ls "$CORES_DIR"/*.oesystemplugin 2>/dev/null | wc -l) cores"
    log "Frameworks: $(ls "$FRAMEWORKS_DIR" 2>/dev/null | wc -l) frameworks"
    log "Team ID: $TEAM_ID"
    log "Notarized: $([ $ENABLE_NOTARIZE -eq 1 ] && echo "Yes" || echo "No")"
    log "=========================================="
}

# Main execution
main() {
    log "OpenEmu Release Build Script"
    log "Workspace: $(basename $WORKSPACE)"
    [ $EXPERIMENTAL -eq 1 ] && log "Mode: EXPERIMENTAL (includes additional cores)"
    log "Team ID: $TEAM_ID"
    log "Configuration: $CONFIGURATION"
    log ""

    verify_prerequisites

    if [ $SKIP_BUILD -eq 0 ]; then
        build_workspace
        sign_app
    else
        log "Skipping build (using existing artifacts)"
    fi

    if [ $ENABLE_NOTARIZE -eq 1 ]; then
        notarize_app
    else
        log "Notarization disabled (use --notarize to enable)"
    fi

    organize_release
    print_summary
}

# Run main
main "$@"

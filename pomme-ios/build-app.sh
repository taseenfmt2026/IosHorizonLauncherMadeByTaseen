#!/usr/bin/env bash
set -euo pipefail

case "$PLATFORM_NAME" in
    iphonesimulator) triple=aarch64-apple-ios-sim platform=ios-simulator ;;
    iphoneos) triple=aarch64-apple-ios platform=ios ;;
    *) echo "error: unsupported platform $PLATFORM_NAME" >&2; exit 1 ;;
esac

profile=debug
release=
if [ "$CONFIGURATION" = Release ]; then
    profile=release
    release=--release
fi

app="$TARGET_BUILD_DIR/$WRAPPER_NAME"
frameworks="$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"

export PATH="$HOME/.cargo/bin:$PATH"

unset SDKROOT LIBRARY_PATH

cd "$PROJECT_DIR/.."

# Keep shaderc from treating the MoltenVK staging directory
# as a complete Vulkan SDK.
if [ -n "${VULKAN_SDK:-}" ] && [ -d "${VULKAN_SDK}/lib" ]; then
    export SHADERC_LIB_DIR="${VULKAN_SDK}/lib"
else
    SHADERC_LIB_DIR="$PWD/target/shaderc-empty-lib"
    mkdir -p "$SHADERC_LIB_DIR"
    export SHADERC_LIB_DIR
fi

# Stage MoltenVK separately, then expose it for the app's Vulkan linking.
MOLTENVK_SDK="$(python3 tools/fetch_moltenvk.py "$platform")"
export VULKAN_SDK="$MOLTENVK_SDK"

cargo build -p pomme-ios --target "$triple" ${release:+"$release"}

mkdir -p "$app" "$frameworks"

if ! cmp -s "target/$triple/$profile/pomme-ios" "$app/$EXECUTABLE_NAME"; then
    cp "target/$triple/$profile/pomme-ios" "$app/$EXECUTABLE_NAME"
fi

python3 tools/build_openal.py "$platform" "$frameworks"

if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
    codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" --timestamp=none \
        "$frameworks/soft_oal.framework"
fi

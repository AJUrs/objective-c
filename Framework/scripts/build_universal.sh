#!/bin/sh

set -e
FRAMEWORKS_PATH="${BUILD_DIR}/Frameworks"
FRAMEWORK_NAME="PubNub"
PRODUCTS_PATH="${SRCROOT}/Products"

# Clean up from previous builds
if [[ -d "${FRAMEWORKS_PATH}" ]]; then
    rm -R "${FRAMEWORKS_PATH}"
fi
if [[ -d "${PRODUCTS_PATH}" ]]; then
    rm -R "${PRODUCTS_PATH}"
fi

# Build library with dependencies for iPhoneOS (ARM binary slice)
echo "Building ${FRAMEWORK_NAME} for iPhoneOS..."
xcrun --no-cache xcodebuild -project "${PROJECT_FILE_PATH}" -target "${FRAMEWORK_NAME}" -configuration "${CONFIGURATION}" -sdk iphoneos BUILD_DIR="${BUILD_DIR}" OBJROOT="${OBJROOT}" BUILD_ROOT="${BUILD_ROOT}" SYMROOT="${SYMROOT}" ONLY_ACTIVE_ARCH=NO $ACTION > /dev/null
echo "Built ${FRAMEWORK_NAME} for iPhoneOS"

# Build library with dependencies for Simulator (x86 binary slice)
echo "Building ${FRAMEWORK_NAME} for Simulator..."
xcrun --no-cache xcodebuild -project "${PROJECT_FILE_PATH}" -target "${FRAMEWORK_NAME}" -configuration "${CONFIGURATION}" -sdk iphonesimulator BUILD_DIR="${BUILD_DIR}" OBJROOT="${OBJROOT}" BUILD_ROOT="${BUILD_ROOT}" SYMROOT="${SYMROOT}" ONLY_ACTIVE_ARCH=NO $ACTION > /dev/null
echo "Built ${FRAMEWORK_NAME} for Simulator..."

# Building universal binary
echo "Building universal framework..."
echo "Artifacts stored in: ${BUILD_DIR}"
BUILT_FRAMEWORKS=("CocoaLumberjack" "PubNub")
IPHONE_OS_ARTIFACTS_PATH="${BUILD_DIR}/${CONFIGURATION}-iphoneos"
SIMULATOR_ARTIFACTS_PATH="${BUILD_DIR}/${CONFIGURATION}-iphonesimulator"

## Prepare folders
mkdir -p "${FRAMEWORKS_PATH}"
mkdir -p "${PRODUCTS_PATH}"

# Copy ARM binaries and build "fat" binary for each built framework.
for frameworkName in "${BUILT_FRAMEWORKS[@]}"
do
    FRAMEWORK_BUNDLE_NAME="${frameworkName}.framework"
    FRAMEWORK_ARM_BUILD_PATH="${IPHONE_OS_ARTIFACTS_PATH}/${FRAMEWORK_BUNDLE_NAME}"
    FRAMEWORK_SIM_BUILD_PATH="${SIMULATOR_ARTIFACTS_PATH}/${FRAMEWORK_BUNDLE_NAME}"
    FRAMEWORK_DESTINATION_PATH="${FRAMEWORKS_PATH}/${FRAMEWORK_BUNDLE_NAME}"
    cp -r "${FRAMEWORK_ARM_BUILD_PATH}" "${FRAMEWORK_DESTINATION_PATH}"
    xcrun lipo -create "${FRAMEWORK_DESTINATION_PATH}/${frameworkName}" "${FRAMEWORK_SIM_BUILD_PATH}/${frameworkName}" -output "${FRAMEWORK_DESTINATION_PATH}/${frameworkName}"
    cp -r "${FRAMEWORKS_PATH}/${FRAMEWORK_BUNDLE_NAME}" "${PRODUCTS_PATH}/${FRAMEWORK_BUNDLE_NAME}"
done
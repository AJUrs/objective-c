#!/bin/sh

set -e

if [[ ${BUILDING_UNIVERSAL_FRAMEWORK:=0} == 0 ]]; then

    PRODUCTS_PATH="${SRCROOT}/Products"
    BUILT_FRAMEWORKS=("CocoaLumberjack" "PubNub")
    if [[ $PLATFORM_NAME =~ (macosx) ]]; then
        ARTIFACTS_PATH="${BUILD_DIR}/${CONFIGURATION}"
    else
        ARTIFACTS_PATH="${BUILD_DIR}/${CONFIGURATION}-${PLATFORM_NAME}"
    fi

    # Clean up from previous builds
    [[ -d "${PRODUCTS_PATH}" ]] && rm -R "${PRODUCTS_PATH}"
    mkdir -p "${PRODUCTS_PATH}"

    # Copy frameworks to products folder.
    for frameworkName in "${BUILT_FRAMEWORKS[@]}"
    do
        if [[ ${BUILDING_STATIC_FRAMEWORK:=0} == 0 ]]; then
            FRAMEWORK_BUNDLE_NAME="${frameworkName}.framework"
            FRAMEWORK_BUILD_PATH="${ARTIFACTS_PATH}/${FRAMEWORK_BUNDLE_NAME}"
        else
            FRAMEWORK_BUNDLE_NAME="PubNub.framework"
            FRAMEWORK_BUILD_PATH="${ARTIFACTS_PATH}"
        fi
        FRAMEWORK_TARGET_PATH="${PRODUCTS_PATH}/${FRAMEWORK_BUNDLE_NAME}"

        if [[ ${BUILDING_STATIC_FRAMEWORK:=0} == 0 ]]; then
            cp -RP "${FRAMEWORK_BUILD_PATH}" "${FRAMEWORK_TARGET_PATH}"
        else
            [[ ! -d "${FRAMEWORK_TARGET_PATH}" ]] && mkdir -p "${FRAMEWORK_TARGET_PATH}"
            if [[ ! -d "${FRAMEWORK_TARGET_PATH}/Headers" ]]; then
                cp -RP "${FRAMEWORK_BUILD_PATH}/Headers" "${FRAMEWORK_TARGET_PATH}/Headers"
                cp "${FRAMEWORK_BUILD_PATH}/PubNub-iOS-Info.plist" "${FRAMEWORK_TARGET_PATH}/Info.plist"
            fi
            cp "${FRAMEWORK_BUILD_PATH}/${frameworkName}.a" "${FRAMEWORK_TARGET_PATH}/${frameworkName}"
        fi
    done
fi

#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=camellia
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done
if [ -z "${SRC}" ]; then
    SRC="adb"
fi

# Patch/fix blobs
function blob_fixup {
    case "$1" in
    vendor/etc/init/vendor.mediatek.hardware.mtkpower@1.0-service.rc)
        echo "$(cat ${2}) input" > "${2}"
        ;;
    system/lib64/libsink.so)
        "${PATCHELF}" --add-needed "libshim_vtservice.so" "${2}"
	;;
    vendor/bin/hw/android.hardware.media.c2@1.2-mediatek*)
       "$PATCHELF" --replace-needed "libavservices_minijail_vendor.so" "libavservices_minijail.so" "$2"
        ;;
    vendor/bin/hw/vendor.mediatek.hardware.mtkpower@1.0-service)
        "$PATCHELF" --replace-needed "android.hardware.power-V2-ndk_platform.so" "android.hardware.power-V2-ndk.so" "${2}"
        ;;
    vendor/bin/hw/android.hardware.gnss-service.mediatek)
        ;&
    vendor/lib64/hw/android.hardware.gnss-impl-mediatek.so)
       "$PATCHELF" --replace-needed "android.hardware.gnss-V1-ndk_platform.so" "android.hardware.gnss-V1-ndk.so" "${2}"
        ;;
    vendor/bin/hw/android.hardware.memtrack-service.mediatek)
       "$PATCHELF" --replace-needed "android.hardware.memtrack-V1-ndk_platform.so" "android.hardware.memtrack-V1-ndk.so" "${2}"
        ;;
    vendor/lib*/hw/vendor.mediatek.hardware.pq@2.13-impl.so)
	;&
    vendor/bin/hw/camerahalserver)
        "${PATCHELF}" --replace-needed "libutils.so" "libutils-v32.so" "${2}"
        ;;
    vendor/lib64/hw/android.hardware.camera.provider@2.6-impl-mediatek.so)
        grep -q "libcamera_metadata_shim.so" "${2}" || "${PATCHELF}" --add-needed "libcamera_metadata_shim.so" "${2}"
        ;;
    vendor/bin/mi_thermald)
        sed -i 's/%d\/on/%d\/../g' "${2}"
        ;;
    esac
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"

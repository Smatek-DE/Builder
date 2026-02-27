#!/bin/bash
usage()
{
    echo "USAGE: [-B] [-A] [-C]"
    echo "  -B = build u-boot"
    echo "  -A = build Android"
    echo "  -C = clean build output"
    exit 1
}

BUILD_DIR=smatek
BUILD_INSTRUCTIONS=false
BUILD_UBOOT=false
BUILD_ANDROID=false
BUILD_CLEAN=false

UBOOT_DIR="u-boot"
RKBIN_DIR="rkbin"
CROSS_COMPILE="aarch64-linux-gnu-"

ANDROID_ROOT=$(cd "$(dirname "$0")" && pwd)

# Eigene TRUST.ini (liegt im Projektverzeichnis, nicht in rkbin)
TRUST_INI="${ANDROID_ROOT}/trust/RK3568TRUST.ini"

# Blobs automatisch ermitteln (neueste Version jeweils)
BL31=$(ls ${ANDROID_ROOT}/${RKBIN_DIR}/bin/rk35/rk3568_bl31_v*.elf   2>/dev/null | grep -v "rt_\|ultra_\|cpu3_\|l3_part" | tail -1)
BL32=$(ls ${ANDROID_ROOT}/${RKBIN_DIR}/bin/rk35/rk3568_bl32_v*.bin   2>/dev/null | tail -1)
DDR=$(ls  ${ANDROID_ROOT}/${RKBIN_DIR}/bin/rk35/rk3568_ddr_1056MHz_v*.bin 2>/dev/null | grep -v "eyescan" | tail -1)

# check pass argument
while getopts "ABC" arg
do
    case $arg in
        A)
            echo "will build Android"
            BUILD_ANDROID=true
            BUILD_INSTRUCTIONS=true
            ;;
        B)
            echo "will build U-Boot"
            BUILD_UBOOT=true
            BUILD_INSTRUCTIONS=true
            ;;
        C)
            BUILD_CLEAN=true
            BUILD_INSTRUCTIONS=true
            ;;
        ?)
            usage ;;
    esac
done

# Print usage/help
if [ "$BUILD_INSTRUCTIONS" = false ] ; then
    usage
fi

if [ ! -d "$BUILD_DIR" ]; then
    mkdir -p "$BUILD_DIR"
fi

# build clean
if [ "$BUILD_CLEAN" = true ] ; then
    echo ">>> Cleaning build output..."
    rm -rf "${BUILD_DIR:?}/"*
    echo ">>> Clean done."
fi

# U-Boot bauen
if [ "$BUILD_UBOOT" = true ]; then
    echo ">>> Building U-Boot..."
    echo "    BL31      : ${BL31}"
    echo "    BL32      : ${BL32}"
    echo "    DDR       : ${DDR}"
    echo "    TRUST INI : ${TRUST_INI}"

    # Blob-Validierung
    for f in "$BL31" "$BL32" "$DDR"; do
        if [ -z "$f" ] || [ ! -f "$f" ]; then
            echo "ERROR: Required blob not found: $f"
            echo "       Check rkbin/bin/rk35/ for rk3568_bl31_v*.elf, rk3568_bl32_v*.bin, rk3568_ddr_1056MHz_v*.bin"
            exit 1
        fi
    done

    if [ ! -f "${TRUST_INI}" ]; then
        echo "ERROR: TRUST ini not found: ${TRUST_INI}"
        exit 1
    fi

    cd ${UBOOT_DIR} || exit

    # Compiler-Pfad in make.sh patchen falls noch nicht geschehen
    if grep -q "gcc-linaro-6.3.1-2017.05" make.sh; then
        echo ">>> Patching make.sh compiler path..."
        sed -i 's|CROSS_COMPILE_ARM64=../prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-|CROSS_COMPILE_ARM64=/usr/bin/aarch64-linux-gnu-|' make.sh
    fi

    # Rockchip make.sh: BL31 per Argument, BL32/OP-TEE ueber eigene TRUST.ini
    ./make.sh rk3568 --bl31 ${BL31} ${TRUST_INI}

    if [ $? -ne 0 ]; then
        echo "ERROR: U-Boot build failed!"
        exit 1
    fi

    echo ">>> Copying U-Boot artifacts..."
    cp uboot.img    ../${BUILD_DIR}/
    cp *loader*.bin ../${BUILD_DIR}/ 2>/dev/null

    echo ""
    echo ">>> U-Boot build successful!"
    echo "    Output: ${ANDROID_ROOT}/${BUILD_DIR}/"
    ls -lh ../${BUILD_DIR}/
    cd ..
fi

# Android bauen
if [ "$BUILD_ANDROID" = true ]; then
    echo ">>> Building Android..."
    # kommt noch
fi

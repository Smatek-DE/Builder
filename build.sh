#!/bin/bash
usage()
{
    echo "USAGE: [-B] [-A]"
    echo "No ARGS means use default build option                  "
    echo "  -B = build u-boot                                     "
    echo "  -A = build Android                                    "
    exit 1
}

BUILD_DIR=smatek
BUILD_UBOOT=false
BUILD_ANDROID=false

# Pfade
UBOOT_DIR="u-boot"
RKBIN_DIR="rkbin"
CROSS_COMPILE="aarch64-linux-gnu-"

# rkbin Binaries (Versionen ggf. anpassen)
BL31=$(ls ${RKBIN_DIR}/bin/rk35/rk3568_bl31_*.elf | tail -1)
DDR=$(ls ${RKBIN_DIR}/bin/rk35/rk3568_ddr_*MHz_*.bin | tail -1)

# check pass argument
while getopts "AB" arg
do
    case $arg in
        A)
            echo "will build Android"
            BUILD_ANDROID=true
            ;;
        B)
            echo "will build U-Boot"
            BUILD_UBOOT=true
            ;;
        ?)
            usage ;;
    esac
done

if [ ! -d "$BUILD_DIR/release" ]; then
    mkdir -p "$BUILD_DIR/release"
fi

# build clean
if [ "$BUILD_CLEAN" = true ] ; then
    rm "${BUILD_DIR:?}/*" -rf
fi

# U-Boot bauen
if [ "$BUILD_UBOOT" = true ]; then
    echo ">>> Building U-Boot..."
    cd ${UBOOT_DIR} || exit

    export ARCH=arm64
    export CROSS_COMPILE=${CROSS_COMPILE}

    make rk3568_defconfig
    make -j$(nproc) BL31=${BL31} ROCKCHIP_TPL=${DDR}

    if [ $? -ne 0 ]; then
        echo "ERROR: U-Boot build failed!"
        exit 1
    fi

    echo ">>> Copying U-Boot artifacts..."
    cp uboot.img ../${BUILD_DIR}/release/
    cp *loader*.bin ../${BUILD_DIR}/release/ 2>/dev/null

    echo ">>> U-Boot build successful!"
    cd ..
fi

# Android bauen
if [ "$BUILD_ANDROID" = true ]; then
    echo ">>> Building Android..."
    # kommt noch
fi

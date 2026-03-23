#!/bin/bash
usage()
{
    echo "USAGE: [-B] [-A] [-C] [-R] [-K]"
    echo "  -B = build u-boot"
    echo "  -K = build Kernel"
    echo "  -A = build Android"
    echo "  -C = clean build output"
    echo "  -R = Refresh Repositorys"
    exit 1
}

# Makefile-Patch Funktion
patch_kernel_makefile() {
    # ToDo: automatically find Makefile.append on these paths (for dynamic dts configurations)
    KERNEL_MAKEFILE="${ANDROID_ROOT}/kernel/rockchip/arch/arm64/boot/dts/rockchip/Makefile"
    APPEND_FILE="${ANDROID_ROOT}/kernel/rockchip/arch/arm64/boot/dts/rockchip/Makefile.append"

    if ! grep -q "rk3566-smatek-s9pe-nz.dtb" "${KERNEL_MAKEFILE}"; then
        cat "${APPEND_FILE}" >> "${KERNEL_MAKEFILE}"
        echo ">>> Kernel Makefile patched."
    else
        echo ">>> Kernel Makefile already patched, skipping."
    fi
}

patch_additional() {
    # WifiTrackerLib prüfen und ggf. entfernen
    if ! find . -name "Android.bp" -exec grep -l "name: \"WifiTrackerLib\"" {} \; 2>/dev/null | grep -q .; then
        echo "WifiTrackerLib nicht gefunden - entferne Dependency aus SettingsLib"
        sed -i '/"WifiTrackerLib"/d' frameworks/base/packages/SettingsLib/Android.bp
    fi

    find prebuilts/abi-dumps/vndk/30 -name libwifi-system-iface.so.lsdump -delete

    sed -i '/"libwifi-system-iface"/d' system/connectivity/wificond/Android.bp
    sed -i '/"libwifi-system-iface-test"/d' system/connectivity/wificond/Android.bp
    #sed -i '/libwifi-system-iface.so/d' build/make/target/product/gsi/30.txt
    #echo "" > frameworks/base/tools/protologtool/Android.bp
}

BUILD_DIR=smatek
BUILD_INSTRUCTIONS=false
BUILD_REFRESH=false
BUILD_UBOOT=false
BUILD_KERNEL=false
BUILD_ANDROID=false
BUILD_CLEAN=false

UBOOT_DIR="u-boot"
RKBIN_DIR="rkbin"
CROSS_COMPILE="aarch64-linux-gnu-"

ANDROID_ROOT="$(cd "$(dirname "$0")" && pwd)"

# Eigene TRUST.ini (liegt im Projektverzeichnis, nicht in rkbin)
TRUST_INI="${ANDROID_ROOT}/trust/RK3568TRUST.ini"

# Blobs automatisch ermitteln (neueste Version jeweils)
BL31=$(ls ${ANDROID_ROOT}/${RKBIN_DIR}/bin/rk35/rk3568_bl31_v*.elf   2>/dev/null | grep -v "rt_\|ultra_\|cpu3_\|l3_part" | tail -1)
BL32=$(ls ${ANDROID_ROOT}/${RKBIN_DIR}/bin/rk35/rk3568_bl32_v*.bin   2>/dev/null | tail -1)
DDR=$(ls  ${ANDROID_ROOT}/${RKBIN_DIR}/bin/rk35/rk3568_ddr_1056MHz_v*.bin 2>/dev/null | grep -v "eyescan" | tail -1)

# check pass argument
while getopts "ABCRK" arg
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
R)
    BUILD_REFRESH=true
    BUILD_INSTRUCTIONS=true
    ;;
C)
    BUILD_CLEAN=true
    BUILD_INSTRUCTIONS=true
    ;;
K)
    BUILD_KERNEL=true
    ;;
?)
    usage ;;
esac
done

# Print usage/help
if [ "$BUILD_INSTRUCTIONS" = false ] ; then
    usage
fi

# Refresh Repositorys
if [ "$BUILD_REFRESH" = true ] ; then
    echo ">>> Refreshing repositories..."
    git -C "${ANDROID_ROOT}/.repo/manifests" pull
    repo sync -j15 --force-remove-dirty --force-sync --prune
    patch_kernel_makefile
    echo ">>> Repository refresh done."
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

# Kernel bauen
if [ "$BUILD_KERNEL" = true ]; then
    echo ">>> Building Kernel..."
    cd "$ANDROID_ROOT/kernel/rockchip"

    export ARCH=arm64
    export CROSS_COMPILE="$ANDROID_ROOT/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-"
    export CC="$ANDROID_ROOT/prebuilts/clang/host/linux-x86/clang-r383902b1/bin/clang"
    export CLANG_TRIPLE=aarch64-linux-gnu-

    make rockchip_defconfig CC=$CC CROSS_COMPILE=$CROSS_COMPILE CLANG_TRIPLE=$CLANG_TRIPLE
    make -j$(nproc) Image dtbs CC=$CC CROSS_COMPILE=$CROSS_COMPILE CLANG_TRIPLE=$CLANG_TRIPLE

    # Zurück ins Root-Verzeichnis — explizit absolut
    cd "$ANDROID_ROOT"

    echo ">>> Moving Kernel..."
    mkdir -p out/target/product/rk3566/
    cp kernel/rockchip/arch/arm64/boot/Image out/target/product/rk3566/kernel
    cp kernel/rockchip/arch/arm64/boot/dts/rockchip/rk3566-smatek-s9pe-nz.dtb out/target/product/rk3566/dtb.img

    # Prüfen ob cp erfolgreich war
    ls -lh out/target/product/rk3566/kernel && echo ">>> Kernel copy OK" || { echo ">>> Kernel copy FAILED"; exit 1; }
fi

# Android bauen
if [ "$BUILD_ANDROID" = true ]; then
    patch_kernel_makefile
    patch_additional

    echo ">>> Building Android..."
    source build/envsetup.sh
    lunch smatek_rk3566-userdebug
    m -j$(nproc)
fi

echo ">>> Build done."
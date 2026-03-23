#!/bin/bash

usage() {
    echo "USAGE: [-B] [-A] [-C] [-R] [-K] [-T]"
    echo "  -B = build u-boot"
    echo "  -K = build Kernel"
    echo "  -A = build Android"
    echo "  -T = build Tools"
    echo "  -C = clean build output"
    echo "  -R = Refresh Repositorys"
    exit 1
}

# Prüft ob eine Datei existiert, bricht sonst mit Fehlermeldung ab
require_file() {
    local file="$1"
    local desc="${2:-$1}"
	
    if [ ! -f "$file" ]; then
        echo "ERROR: Required file not found: $desc"
        echo "       Expected at: $file"
        exit 1
    fi
}

# Kopiert eine Datei nach Existenzprüfung
copy_artifact() {
    local src="$1"
    local dst="$2"
    local desc="${3:-$(basename "$src")}"
    require_file "$src" "$desc"
    cp "$src" "$dst"
    echo "    [OK] $desc → $dst"
}

patch_kernel_makefile() {
    local KERNEL_MAKEFILE="${ANDROID_ROOT}/kernel/rockchip/arch/arm64/boot/dts/rockchip/Makefile"
    local APPEND_FILE="${ANDROID_ROOT}/kernel/rockchip/arch/arm64/boot/dts/rockchip/Makefile.append"

    require_file "$APPEND_FILE" "Kernel Makefile.append"

    if ! grep -q "rk3566-smatek-s9pe-nz.dtb" "${KERNEL_MAKEFILE}"; then
        cat "${APPEND_FILE}" >> "${KERNEL_MAKEFILE}"
        echo ">>> Kernel Makefile patched."
    else
        echo ">>> Kernel Makefile already patched, skipping."
    fi
}

patch_additional() {
    # Fix Wifi library
    grep -q 'shared_libs: \["libwifi-system-iface"\]' system/connectivity/wificond/Android.bp || \
        sed -i 's/    include_dirs: \["system\/connectivity"\],/    include_dirs: ["system\/connectivity"],\n    shared_libs: ["libwifi-system-iface"],/' system/connectivity/wificond/Android.bp
    echo ">>> Additional patches applied."
}

# Konfiguration
ANDROID_ROOT="$(cd "$(dirname "$0")" && pwd)"

BUILD_DIR="${ANDROID_ROOT}/smatek"
UBOOT_DIR="${ANDROID_ROOT}/u-boot"
RKBIN_DIR="${ANDROID_ROOT}/rkbin"
AOSP_OUT="${ANDROID_ROOT}/out/target/product/rk3566"

CROSS_COMPILE="aarch64-linux-gnu-"

# Eigene TRUST.ini (liegt im Projektverzeichnis, nicht in rkbin)
TRUST_INI="${ANDROID_ROOT}/trust/RK3568TRUST.ini"

# Blobs automatisch ermitteln (neueste Version jeweils)
BL31=$(ls "${RKBIN_DIR}/bin/rk35/rk3568_bl31_v"*.elf   2>/dev/null | grep -v "rt_\|ultra_\|cpu3_\|l3_part" | tail -1)
BL32=$(ls "${RKBIN_DIR}/bin/rk35/rk3568_bl32_v"*.bin   2>/dev/null | tail -1)
DDR=$(ls  "${RKBIN_DIR}/bin/rk35/rk3568_ddr_1056MHz_v"*.bin 2>/dev/null | grep -v "eyescan" | tail -1)

BUILD_INSTRUCTIONS=false
BUILD_REFRESH=false
BUILD_TOOLS=false
BUILD_UBOOT=false
BUILD_KERNEL=false
BUILD_ANDROID=false
BUILD_CLEAN=false

while getopts "ABCRKT" arg; do
    case $arg in
        A) echo "will build Android";  BUILD_ANDROID=true;  BUILD_INSTRUCTIONS=true ;;
        B) echo "will build U-Boot";   BUILD_UBOOT=true;    BUILD_INSTRUCTIONS=true ;;
        R)                             BUILD_REFRESH=true;  BUILD_INSTRUCTIONS=true ;;
        C)                             BUILD_CLEAN=true;    BUILD_INSTRUCTIONS=true ;;
        K)                             BUILD_KERNEL=true;   BUILD_INSTRUCTIONS=true ;;
        T)                             BUILD_TOOLS=true;    BUILD_INSTRUCTIONS=true ;;
        ?) usage ;;
    esac
done

if [ "$BUILD_INSTRUCTIONS" = false ]; then
    usage
fi

mkdir -p "$BUILD_DIR"

if [ "$BUILD_REFRESH" = true ]; then
    echo ">>> Refreshing repositories..."
    git -C "${ANDROID_ROOT}/.repo/manifests" pull
    repo sync -j15 --force-remove-dirty --force-sync --prune
    patch_kernel_makefile
    echo ">>> Repository refresh done."
fi

if [ "$BUILD_CLEAN" = true ]; then
    echo ">>> Cleaning build output..."
    rm -rf "${BUILD_DIR:?}/"*
    echo ">>> Clean done."
fi

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

    require_file "${TRUST_INI}" "TRUST ini"

    cd "${UBOOT_DIR}"

    # Compiler-Pfad in make.sh patchen falls noch nicht geschehen
    if grep -q "gcc-linaro-6.3.1-2017.05" make.sh; then
        echo ">>> Patching make.sh compiler path..."
        sed -i 's|CROSS_COMPILE_ARM64=../prebuilts/gcc/linux-x86/aarch64/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-|CROSS_COMPILE_ARM64=/usr/bin/aarch64-linux-gnu-|' make.sh
    fi

    ./make.sh rk3568 --bl31 "${BL31}" "${TRUST_INI}"

    cd "${RKBIN_DIR}"
    tools/loaderimage --pack --trustos \
        RKTRUST/RK3566TRUST_ULTRA.ini \
        "${BUILD_DIR}/trust.img" 0x43000000

    cd "${UBOOT_DIR}"
    echo ">>> Copying U-Boot artifacts..."
    copy_artifact "${UBOOT_DIR}/uboot.img"         "${BUILD_DIR}/uboot.img"      "uboot.img"
    # Loader-Binary (Name variiert je nach Build)
    LOADER_BIN=$(ls "${UBOOT_DIR}/"*loader*.bin 2>/dev/null | head -1)
    if [ -n "$LOADER_BIN" ]; then
        copy_artifact "$LOADER_BIN" "${BUILD_DIR}/$(basename "$LOADER_BIN")" "MiniLoaderAll.bin"
    else
        echo "    [WARN] No loader*.bin found in ${UBOOT_DIR}"
    fi

    echo ""
    echo ">>> U-Boot build successful!"
    echo "    Output: ${BUILD_DIR}/"
    ls -lh "${BUILD_DIR}/"
    cd "${ANDROID_ROOT}"
fi

if [ "$BUILD_KERNEL" = true ]; then
    echo ">>> Building Kernel..."
    cd "${ANDROID_ROOT}/kernel/rockchip"

    export ARCH=arm64
    export CROSS_COMPILE="${ANDROID_ROOT}/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-"
    export CC="${ANDROID_ROOT}/prebuilts/clang/host/linux-x86/clang-r383902b1/bin/clang"
    export CLANG_TRIPLE=aarch64-linux-gnu-

    make rockchip_defconfig CC="$CC" CROSS_COMPILE="$CROSS_COMPILE" CLANG_TRIPLE="$CLANG_TRIPLE"
    make -j"$(nproc)" Image dtbs CC="$CC" CROSS_COMPILE="$CROSS_COMPILE" CLANG_TRIPLE="$CLANG_TRIPLE"

    cd "${ANDROID_ROOT}"

    echo ">>> Moving Kernel..."
    mkdir -p "${AOSP_OUT}"

    copy_artifact \
        "${ANDROID_ROOT}/kernel/rockchip/arch/arm64/boot/Image" \
        "${AOSP_OUT}/kernel" \
        "Kernel Image"

    copy_artifact \
        "${ANDROID_ROOT}/kernel/rockchip/arch/arm64/boot/dts/rockchip/rk3566-smatek-s9pe-nz.dtb" \
        "${AOSP_OUT}/dtb.img" \
        "Device Tree (dtb.img)"

    echo ">>> Kernel build successful!"
fi


if [ "$BUILD_TOOLS" = true ]; then
    cd ~/Android
    source build/envsetup.sh
    lunch smatek_rk3566-userdebug
    make avbtool -j$(nproc)
fi

if [ "$BUILD_ANDROID" = true ]; then
    patch_kernel_makefile
    patch_additional

    echo ">>> Building Android..."
    #source build/envsetup.sh
    #lunch smatek_rk3566-userdebug
    #m -j$(nproc)

    echo ">>> Copying Android artifacts..."
    copy_artifact "${AOSP_OUT}/boot.img"     "${BUILD_DIR}/boot.img"     "boot.img"
    copy_artifact "${AOSP_OUT}/recovery.img" "${BUILD_DIR}/recovery.img" "recovery.img"
    copy_artifact "${AOSP_OUT}/system.img"   "${BUILD_DIR}/system.img"   "system.img"
    copy_artifact "${AOSP_OUT}/vendor.img"   "${BUILD_DIR}/vendor.img"   "vendor.img"
    copy_artifact "${AOSP_OUT}/product.img"  "${BUILD_DIR}/product.img"  "product.img"

    # vbmeta.img
    printf 'AVB0' > ~/Android/smatek/vbmeta.img
    dd if=/dev/zero bs=1 count=$((1048576 - 4)) >> ~/Android/smatek/vbmeta.img 2>/dev/null
    xxd ~/Android/smatek/vbmeta.img | head -4
    ls -lh ~/Android/smatek/vbmeta.img

    # misc.img — immer leer
    dd if=/dev/zero of="${BUILD_DIR}/misc.img" bs=512 count=8192 status=none
    echo "    [OK] misc.img (empty)"
	
	# dtbo.img TODO
    copy_artifact "/mnt/f/BABTouchpanel/Backups/backup_dtbo.img" "${BUILD_DIR}/dtbo.img" "dtbo.img (original backup)"
    #dd if=/dev/zero of=~/Android/smatek/dtbo.img bs=512 count=8192 status=none
    #echo "    [OK] dtbo.img (empty)"

    # Make images RAW
    simg2img /root/Android/smatek/system.img  /root/Android/smatek/system_raw.img
    simg2img /root/Android/smatek/vendor.img  /root/Android/smatek/vendor_raw.img
    simg2img /root/Android/smatek/product.img /root/Android/smatek/product_raw.img

    SYSTEM_SIZE=$(stat -c%s /root/Android/smatek/system_raw.img)
    VENDOR_SIZE=$(stat -c%s /root/Android/smatek/vendor_raw.img)
    PRODUCT_SIZE=$(stat -c%s /root/Android/smatek/product_raw.img)
    TOTAL=$((SYSTEM_SIZE + VENDOR_SIZE + PRODUCT_SIZE + 104857600)) # +100MB safety space

    lpmake \
        --metadata-size 65536 \
        --super-name super \
        --metadata-slots 2 \
        --device super:${TOTAL} \
        --group main:${TOTAL} \
        --partition system:readonly:${SYSTEM_SIZE}:main \
        --image system=/root/Android/smatek/system_raw.img \
        --partition vendor:readonly:${VENDOR_SIZE}:main \
        --image vendor=/root/Android/smatek/vendor_raw.img \
        --partition product:readonly:${PRODUCT_SIZE}:main \
        --image product=/root/Android/smatek/product_raw.img \
        --sparse \
        --output /root/Android/smatek/super.img

    echo ""
    echo ">>> Android build successful!"
    echo "    Output: ${BUILD_DIR}/"
    ls -lh "${BUILD_DIR}/"
    cd "${ANDROID_ROOT}"
fi

echo ">>> Build done."
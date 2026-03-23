# BoardConfig for Smatek RK3566
# Partition sizes calculated from parameter.txt (512-byte sectors)
# Device properties verified against device_properties_backup.txt
#

# -------------------------------------------------------
# Architektur (ro.bionic.arch=arm64, cpu_variant=cortex-a55)
# -------------------------------------------------------
TARGET_ARCH         := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI      := arm64-v8a
TARGET_CPU_VARIANT  := cortex-a55

# 32-bit Kompatibilität (ro.bionic.2nd_arch=arm)
TARGET_2ND_ARCH         := arm
TARGET_2ND_ARCH_VARIANT := armv8-2a
TARGET_2ND_CPU_ABI      := armeabi-v7a
TARGET_2ND_CPU_ABI2     := armeabi
TARGET_2ND_CPU_VARIANT  := cortex-a55

# -------------------------------------------------------
# Kernel (aus Source bauen)
# -------------------------------------------------------
TARGET_KERNEL_ARCH   := arm64
TARGET_KERNEL_SOURCE := kernel/rockchip
TARGET_KERNEL_CONFIG := rockchip_defconfig

# Boot-Console: ttyFIQ0 (ro.boot.console=ttyFIQ0)
BOARD_KERNEL_CMDLINE := \
    console=ttyFIQ0 \
    androidboot.hardware=rk30board \
    androidboot.selinux=permissive \
    ro.boot.noril=true

BOARD_KERNEL_BASE     := 0x00200000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_OFFSET   := 0x00008000
BOARD_RAMDISK_OFFSET  := 0x01000000
BOARD_TAGS_OFFSET     := 0x00000100

# Boot Header Version 2 (Standard für RK3566/Android 11)
BOARD_BOOT_HEADER_VERSION := 2
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)

# DTB im Boot-Image einbetten
BOARD_INCLUDE_DTB_IN_BOOTIMG := true

# Boot-Devices (ro.boot.boot_devices=fe310000.sdhci,fe330000.nandc)
BOARD_BOOT_DEVICES := fe310000.sdhci fe330000.nandc

# -------------------------------------------------------
# AVB - Verified Boot
# (ro.boot.verifiedbootstate=orange → unlocked)
# -------------------------------------------------------
BOARD_AVB_ENABLE := false
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3

# ToDo: Ggf. für später mal:
# BOARD_AVB_ENABLE := true
# AVB Recovery Key (eigenen Key generieren)
# BOARD_AVB_RECOVERY_KEY_PATH         := external/avb/test/data/testkey_rsa4096.pem
# BOARD_AVB_RECOVERY_ALGORITHM        := SHA256_RSA4096
# BOARD_AVB_RECOVERY_ROLLBACK_INDEX   := $(PLATFORM_SECURITY_PATCH_TIMESTAMP)
# BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1

# -------------------------------------------------------
# Partitionsgrößen (exakt aus parameter.txt, Sektor × 512)
#
# Format: 0x<size>@0x<offset>(<name>)
# -------------------------------------------------------

# misc: 0x00002000 × 512 = 4.194.304 Bytes (4 MB)
BOARD_MISCIMAGE_PARTITION_SIZE := 4194304

# dtbo: 0x00002000 × 512 = 4.194.304 Bytes (4 MB)
BOARD_DTBOIMAGE_PARTITION_SIZE := 4194304

# vbmeta: 0x00000800 × 512 = 1.048.576 Bytes (1 MB)
BOARD_VBMETAIMAGE_PARTITION_SIZE := 1048576

# boot: 0x00014000 × 512 = 41.943.040 Bytes (40 MB)
BOARD_BOOTIMAGE_PARTITION_SIZE := 41943040

# recovery: 0x00040000 × 512 = 134.217.728 Bytes (128 MB)
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 134217728

# cache: 0x000c0000 × 512 = 402.653.184 Bytes (384 MB)
BOARD_CACHEIMAGE_PARTITION_SIZE    := 402653184
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE  := ext4

# metadata: 0x00008000 × 512 = 16.777.216 Bytes (16 MB)
BOARD_METADATAIMAGE_PARTITION_SIZE := 16777216

# -------------------------------------------------------
# Dynamic Partitions (super)
# super: 0x00614000 × 512 = 3.263.168.512 Bytes (~3.04 GB)
# -------------------------------------------------------
BOARD_SUPER_PARTITION_SIZE   := 3263168512
BOARD_SUPER_PARTITION_GROUPS := smatek_dynamic_partitions

BOARD_SMATEK_DYNAMIC_PARTITIONS_PARTITION_LIST := system vendor product
# Super - 4MB Metadata-Overhead
BOARD_SMATEK_DYNAMIC_PARTITIONS_SIZE := 3258974208

# -------------------------------------------------------
# Dateisysteme
# -------------------------------------------------------
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE      := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE      := ext4
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE     := ext4

TARGET_COPY_OUT_VENDOR  := vendor
TARGET_COPY_OUT_PRODUCT := product

# -------------------------------------------------------
# Recovery
# (ro.minui.pixel_format=RGBX_8888)
# -------------------------------------------------------
BOARD_USES_RECOVERY_AS_BOOT    := false
TARGET_RECOVERY_PIXEL_FORMAT   := RGBX_8888
TARGET_RECOVERY_FSTAB          := device/smatek/rk3566/recovery.fstab

# -------------------------------------------------------
# Treble / VNDK
# (ro.treble.enabled=true, ro.vndk.version=30)
# -------------------------------------------------------
BOARD_VNDK_VERSION := current

# -------------------------------------------------------
# SELinux (permissive wie Original)
# -------------------------------------------------------
BOARD_USES_VENDORIMAGE := true
BOARD_SEPOLICY_DIRS    += device/smatek/rk3566/sepolicy

# -------------------------------------------------------
# WiFi (AP6255, aus sys.wifi.chip)
# -------------------------------------------------------
WPA_SUPPLICANT_VERSION      := VER_0_8_X
BOARD_WPA_SUPPLICANT_DRIVER := NL80211
BOARD_HOSTAPD_DRIVER        := NL80211
BOARD_WLAN_DEVICE           := bcmdhd

# -------------------------------------------------------
# Bluetooth
# (ro.rk.bt_enable=true, vendor.bluetooth-1-0)
# -------------------------------------------------------
BOARD_HAVE_BLUETOOTH := true

# -------------------------------------------------------
# Kein RIL / kein Modem
# (ro.boot.noril=true)
# -------------------------------------------------------
BOARD_PROVIDES_RILD := false

# Module die nicht gebaut werden sollen
DISABLE_PREOPT_MODULES := CarSystemUI
ALLOW_MISSING_DEPENDENCIES := true
DEVICE_MANIFEST_FILE := device/smatek/rk3566/vintf/manifest.xml
# Keine Emulator-Compatibility-Matrix
DEVICE_MATRIX_FILE :=
SKIP_BOOT_JARS_CHECK := true
BOARD_PREBUILT_DTBOIMAGE := $(TARGET_OUT_INTERMEDIATES)/DTBO_OBJ/arch/arm64/boot/dts/rockchip/rk3566-smatek-s9pe-nz.dtbo
WITHOUT_CHECK_API := true
SKIP_API_CHECKS := true

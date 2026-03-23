# Product configuration for Smatek RK3566 device.
# Based on device_properties_backup.txt from target device.
#

# -------------------------------------------------------
# Architecture: arm64 + arm (32-bit compat), cortex-a55
# -------------------------------------------------------
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)

# -------------------------------------------------------
# Minimale System-Basis (kein Emulator, kein Telephony)
# -------------------------------------------------------
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

# -------------------------------------------------------
# System-Ext: Handheld (Settings, SystemUI)
# KEIN telephony_system_ext.mk !
# -------------------------------------------------------
$(call inherit-product, $(SRC_TARGET_DIR)/product/handheld_system_ext.mk)

# -------------------------------------------------------
# Product-Partition Apps
# -------------------------------------------------------
# $(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_product.mk)

# -------------------------------------------------------
# Dynamic Partitions (super partition)
# -------------------------------------------------------
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# -------------------------------------------------------
# Produktidentifikation (aus device_properties_backup.txt)
# -------------------------------------------------------
PRODUCT_NAME        := smatek_rk3566
PRODUCT_DEVICE      := rk3566
PRODUCT_BRAND       := Smatek
PRODUCT_MODEL       := Smatek RK3566
PRODUCT_MANUFACTURER := Smatek

# Android-Version (wie Original: Android 11, SDK 30)
PRODUCT_SHIPPING_API_LEVEL := 30

# Tablet-Charakteristik (ro.build.characteristics=tablet)
PRODUCT_CHARACTERISTICS := tablet

# Locale (aus persist.sys.locale=en-US)
PRODUCT_LOCALES := en_US

# Display-Dichte (ro.sf.lcd_density=240)
PRODUCT_AAPT_CONFIG := normal
PRODUCT_AAPT_PREF_CONFIG := hdpi

# Kein RIL (ro.boot.noril=true, ro.radio.noril=true)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.boot.noril=true \
    ro.radio.noril=true \
    keyguard.no_require_sim=true \
    ril.function.dataonly=1

# Display-Rotation (ro.surface_flinger.primary_display_orientation=ORIENTATION_90)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.surface_flinger.primary_display_orientation=ORIENTATION_90 \
    ro.sf.lcd_density=240

# Recovery-Pixel-Format (ro.minui.pixel_format=RGBX_8888)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.minui.pixel_format=RGBX_8888 \
    ro.minui.default_rotation=ROTATION_RIGHT

# Lockscreen deaktivieren (ro.lockscreen.disable.default=true)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.lockscreen.disable.default=true

# SELinux permissive (wie Original: ro.boot.selinux=permissive)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.boot.selinux=permissive

# Rockchip Board-Platform
PRODUCT_PROPERTY_OVERRIDES += \
    ro.board.platform=rk356x \
    ro.hardware=rk30board \
    ro.boot.hardware=rk30board \
    ro.product.board=rk30sdk

# Dalvik VM (aus device_properties_backup.txt)
PRODUCT_PROPERTY_OVERRIDES += \
    dalvik.vm.heapstartsize=16m \
    dalvik.vm.heapgrowthlimit=256m \
    dalvik.vm.heapsize=512m \
    dalvik.vm.heaptargetutilization=0.5 \
    dalvik.vm.heapminfree=8m \
    dalvik.vm.heapmaxfree=32m \
    dalvik.vm.dex2oat-threads=4 \
    dalvik.vm.boot-dex2oat-threads=4

# WiFi (AP6255 aus sys.wifi.chip)
PRODUCT_PROPERTY_OVERRIDES += \
    wifi.interface=wlan0

# ADB over TCP (service.adb.tcp.port=5555)
PRODUCT_PROPERTY_OVERRIDES += \
    service.adb.tcp.port=5555

# Metalava strict mode deaktivieren
PRODUCT_PROPERTY_OVERRIDES += \
    ro.metalava.strict=false

# Pakete
PRODUCT_PACKAGES_EXCLUDED := \
    CarSystemUI \
    CarSystemUI-core

PRODUCT_PACKAGES += \
    # Hier eigene Apps/Services ergänzen

# APN-Konfiguration entfernen (kein Telephony)
PRODUCT_COPY_FILES := $(filter-out device/sample/etc/apns-full-conf.xml:%,$(PRODUCT_COPY_FILES))

PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false

DEVICE_MANIFEST_FILE := device/smatek/rk3566/vintf/manifest.xml

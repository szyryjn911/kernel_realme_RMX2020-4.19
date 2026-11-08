# RMX2020 4.19 bring-up (temporary boot)

Build (clang, like the 4.14 tree):
    make O=out ARCH=arm64 CC=clang CROSS_COMPILE=aarch64-linux-gnu- LLVM=1 \
         vendor/mt6768_defconfig vendor/rmx2020.config vendor/rmx2020_bringup.config
    make O=out ARCH=arm64 CC=clang ... -j$(nproc)

Boot image: kernel = out/arch/arm64/boot/Image.gz-dtb (dtb appended, BUILD_ARM64_APPENDED_DTB_IMAGE=y)
Reuse the STOCK boot.img ramdisk/header args, only replace the kernel, then:  fastboot boot boot.img

If the bootloader does not apply the (old, 4.14-era) dtbo partition correctly, use the merged dtb:
    scripts/rmx2020_merge_dtb.sh out oppo6769_19741     # -> out/arch/arm64/boot/Image.gz-dtb-oppo6769_19741

What bring-up config changes (rmx2020_bringup.config):
- LTO/CFI/ShadowCallStack off (4.14 tree had them off), KASLR off, cmdline same as the 4.14 tree
- CUSTOM_KERNEL_IMGSENSOR="" : camera sensors are NOT ported, camera will not work, boot is not blocked

Known not-working / unverified: camera, fingerprint, sia81xx amp, NFC, TEE (tkcore/teei), MTK_RAM_CONSOLE/AEE,
boot-mode detection (silence/safe/aging), display/touch/charging are compile-tested only.
Useful logs after a failed boot: /sys/fs/pstore (ramoops needs a reserved-memory node, not added), UART ttyMT3 921600.

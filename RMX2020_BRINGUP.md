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

## Bootloop: "[SSPM] cannot find property" + "Unable to handle kernel paging request" in sspm_mbox_send (via mt_freqhopping_init)
Cause 1 (kernel): the 4.19 SSPM driver failed its probe because the dtb it was given had no `sspm_mem_key`
(4.14 style sspm node). A failed probe unmaps the mailbox, then freqhopping crashes in sspm_mbox_send().
drivers/misc/mediatek/sspm/v1/sspm_reservedmem.c is now tolerant (the key/table are not used for anything).
Cause 2 (boot image): the 4.19 mt6768.dts DOES contain sspm_mem_key, so the kernel was running with a different (stock 4.14)
dtb. With boot header v2 the bootloader takes the dtb from the boot image's own dtb section and ignores the one appended
to the kernel, and an AnyKernel zip keeps the old section.
Check: dtc -I dtb -O dts out/arch/arm64/boot/dts/mediatek/mt6768.dtb | grep sspm_mem_key      (must print the property)
Fix  : python3 scripts/rmx2020_mkboot.py STOCK_BOOT.img out  ->  new-boot.img  (new kernel + new merged dtb, rest from stock)
       fastboot boot new-boot.img      (temporary, nothing is flashed)
Or   : STOCK_BOOT=boot_backup.img bash RMX2020-4.19.sh mkboot

## Which dtb is the kernel really running with? ("RMX2020 dtb check")
drivers/soc/oppo/oppo_dtb_check.c prints one line before any driver probes, e.g.
    RMX2020 dtb check: fdt 167770 bytes, 2100 nodes, sspm_mem_key=1 nvmem-cells=3 phys=1 => 4.19 port dtb OK
or  ... sspm_mem_key=0 ... => LOOKS LIKE THE STOCK 4.14 DTB (the boot image dtb is not the 4.19 one)
Read it from last_kmsg / pstore console (adb shell dmesg | grep "dtb check" if it boots).
The 4.19 drivers that failed one after another (SSPM sspm_mem_key, gpufreq efuse_segment_cell, usb glue phys, scp_dvfs) all
need properties the 4.14 dts does not have, so they are symptoms of the same thing: a 4.14 dtb under the 4.19 kernel.
Null-check/break patches only hide the next failure; the fix is the right dtb (scripts/rmx2020_mkboot.py).

## mkboot needs fdtoverlay
rmx2020_mkboot.py now stops (no image is written) if the overlay cannot be merged into the dtb, because an image with only the
plain mt6768.dtb has none of the RMX2020 hardware nodes (display, touch, charger, battery ...) unless the dtbo partition supplies them.
Install it with:  sudo apt-get update && sudo apt-get install -y device-tree-compiler      (or use --no-merge on purpose)
Confirmed on the device image: header v2 with a 128276 byte dtb section, i.e. the bootloader reads the dtb from the boot image dtb
section and ignores the dtb appended to the kernel.

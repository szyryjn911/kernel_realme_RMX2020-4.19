# RMX2020 (oppo6769) 4.14 -> 4.19 port: status

Base: mt6768-dev/android_kernel_xiaomi_mt6768 branch lineage-23.2 (4.19.325)
Source of RMX2020 code: szyryjn911/android_kernel_realme_RMX2020 branch 17.0 (4.14.357)

## Stage 1 (done, dts level verified)
- arch/arm64/boot/dts/mediatek/oppo6769_{19741,19747,206AC}.dts (+ cust.dtsi per project)
- camera / charger dtsi copied from the 4.14 tree
- mt6768.dts: added nodes needed by the overlays (egis_fp, oplus_fp_common, oplus_fast_charger,
  otg_iddig, flashlights_pascal, flashlights_monet)
- arch/arm64/configs/vendor/rmx2020.config  (use: mt6768_defconfig + rmx2020.config)
- Checked: all three overlays compile (cpp+dtc) and apply to the mt6768 platform dtb (fdtoverlay)

## Stage 2a (done, compile-tested: lcm/ and drivers/soc/oppo/ build with aarch64 gcc 13)
- 7 LCM panels copied + registered in mt65xx_lcm_list.c/.h
- lcm_drv.h: oppo fields added (blmap, brightness_min/max, *_ext timings, enn bias, vddio ctl, cabc/gamma hooks)
- lcm_i2c_oppo.c (gate IC SM5109/OCP2130 via cmdline lcdgateic=...) selected by CONFIG_OPPO_ARCH_FILE
- display: disp_dts_gpio VDDIO18 states, ddp_dsi.c bias/vddio helpers (guarded by CONFIG_OPPO_ARCH_FILE)
- drivers/soc/oppo + include/soc/oppo + update_tpfw_notifier.h; wired into drivers/soc Kconfig/Makefile
- top Makefile: OPLUS_*/VENDOR_EDIT -D macros (from OplusKernelEnvConfig.mk) enabled only when CONFIG_OPPO_ARCH_FILE=y
- NOT yet ported on the display side: panel-name hooks in dispsys/ddp_dsi.c and videox/mtkfb.c, blmap/cabc usage in
  videox/primary_display.c and disp_lcm.c (4.14 has them, 4.19 does not) -> panels compile but backlight map / CABC
  will not be driven until those are ported. update_tpfw_notifier_call_chain() has no implementation yet (link error risk).

## Stage 2b (done, compile-tested)
- drivers/input/touchscreen/oppo_touchscreen (+touch.c/h): NT36525B (nova), ILITEK 9881H_V3 + 9882N build; sys_* -> ksys_*
- drivers/soc/oplus/system + include/soc/oplus/system (oplus_project/get_project etc.); OPLUS_SYSTEM_KERNEL now default n
- update_tpfw_notifier: original definition not found in the 4.14 tree, re-implemented as a plain atomic notifier
  (drivers/soc/oppo/update_tpfw_notifier.c)
- cabc_sun_flag: defined in lcm_i2c_oppo.c (panels use it as a weak extern)
- link-level check: of 412 unresolved symbols in ported objects only cabc_sun_flag (fixed) and ion_hdl2sec_type
  (referenced by stock 4.19 ddp_ovl/ddp_wdma_ex, ion/secure-mem config, not part of this port) had no definition in the source.
  This is a source-level check only, not a real vmlinux link.

## Stage 3 (charging, done = drivers/power/ compiles with aarch64 gcc 13, not linked/booted)
- drivers/power/oplus (126 files) + oplus Kconfig symbols merged into drivers/power/Kconfig
- IMPORTANT: oplus charger is written against the 4.14 MTK charger-manager (consumer) API, which differs from the 4.19
  MTK charger framework. drivers/power/supply/mediatek/{charger,battery,misc} were therefore OVERLAID with the 4.14 tree
  versions (their Makefiles carry the CONFIG_OPLUS_CHARGER_MTK6769 branch). 4.19-only files stay but are not built.
- mt-plat headers from the 4.14 tree: charger_class.h charger_type.h mtk_charger.h mtk_battery.h mtk_gpio.h
  prop_chgalgo_class.h, plus include/linux/hardware_info.h
- compat shims: include/linux/wakelock.h (wakeup_source_register based), include/linux/xlog.h (printk), wakeup_source_init/trash
- power_supply: +48 oplus POWER_SUPPLY_PROP_* in include/linux/power_supply.h; power_supply_attrs[] rebuilt positionally
  (original 4.19 names kept) in drivers/power/supply/power_supply_sysfs.c
- 4.14->4.19 API drift fixed: pm_mutex->system_transition_mutex, class->suspend/resume -> class->pm (dev_pm_ops),
  lbat_user_register() returns a pointer now (gm.lowbat_service is a pointer), rt9467.c brace bug in stock 4.19
- -Werror removed under drivers/power
- RISK: 4.14-BSP charger/battery code on 4.19 PMIC/gauge drivers is untested at runtime.

## Stage 4 (display hooks; video/, lcm/, soc/oppo compile; not linked/booted)
- Auto-merged the oplus-marked hunks (OPLUS_BUG_STABILITY / VENDOR_EDIT / ...) of the 4.14 display stack into
  drivers/misc/mediatek/video/mt6768/{videox,dispsys}: disp_lcm.c (cabc/gamma/backlight remap/resume power/shutdown),
  primary_display.c (resume power, aging-test backlight), ddp_dsi.c (per-panel MIPI clock change),
  mtkfb.c (dynamic MIPI clock hook for the 6 oplus panels), mtk_disp_mgr.c, disp_cust.c (led_rm), disp_recovery.c
- Weak externs written by the display code (oplus_flag_lcd_off, oplus_display_twelvebits_support, cabc_sun_flag) are now
  strongly defined (lcm_i2c_oppo.c); oppo_boot_mode comes from the ported boot driver (drivers/misc/mediatek/boot, see Fix 8)
- mtk_boot_common.h got the OPPO boot mode enums
- Skipped on purpose: oplus lcm_set_reset_pin variant (4.19 version is equivalent when dts_gpio_state == 0), AOD log strings
- primary_display.c: 2 hunks not ported (commented-out widevine ion_free, one DISPCHECK log)
- RISK: panel timing/backlight code is only compile-tested; first boot may show a black screen or wrong backlight.

## Fix 7 (reported from a real build)
- drivers/misc/mediatek/power/mt6768/{mtk_battery_intf.c,misc.c,Makefile} overlaid with the 4.14 versions: the 4.19 file used
  gm->boot_mode which the overlaid 4.14 struct mtk_battery does not have (same reason as the charger/battery overlay).
- Compile sweep of every other dir including the overlaid battery/charger headers (pmic, typec/tcpc, thermal, flashlight, rtc,
  pmic_wrap): 84 objects, 0 errors.

## Fix 8 (undefined symbols from the first real link)
- ported the 4.14 boot drivers: drivers/misc/mediatek/boot (get_boot_mode, is_meta_mode, ...) and boot_reason (get_boot_reason).
  4.19 only has a stub get_boot_mode() returning 0 in hal_kpd.c (now guarded by CONFIG_MTK_BOOT). Needed for off-mode charging / meta mode.
  MEDIATEK_SOLUTION dependency replaced by ARCH_MEDIATEK (symbol does not exist in 4.19).
- led_rm (leds/mt6768 + dts property led_rm), musb_ctrl_host (usb20_host.c, iddig/pinctrl path only: the Monet 19747/0x206AC tcpc path is NOT ported)
- oppo_compat.c: oplus_silence_mode, oplus_fp_silence_mode, oplus_display_cabc_cmdq_support (default false), devinfo_info_set (-> register_device_proc),
  typec_cc_orientation (extern in the always-built Xiaomi tcpc_fusb303.c, defined nowhere)
- nvt_update_firmware: stock 4.19 call for the Xiaomi tianma/dijing NT36672 panels, now a weak extern
- rmx2020.config: 30 Xiaomi (merlin/lancelot) options switched off (TCPC_WUSB3801, SMB1351, FPC/GOODIX fingerprint, LM3697, NFC, TOUCHSCREEN_MTK, ...)

## Fix 12 (first boot: SSPM probe failure -> freqhopping panic)
- sspm/v1/sspm_reservedmem.c: sspm_mem_key / sspm_mem_tbl missing in the dtb no longer fail the probe
  (also fixes a negative of_property_count_u32_elems() wrapping into a huge unsigned loop count)
- scripts/rmx2020_mkboot.py (+ `mkboot` in RMX2020-4.19.sh): repack the STOCK boot.img with the new kernel and the new merged dtb;
  tested on synthetic header v1/v2 images (kernel, dtb, ramdisk, cmdline, offsets verified after unpack)
- Likely root cause of the bootloop: the bootloader used the stock 4.14 dtb from the boot image dtb section (not verified on the device)

## Fix 13
- oppo_dtb_check.c: early_initcall that logs whether the running dtb has sspm_mem_key (4.19 port dtb) or not (stock 4.14 dtb)
- user-side band-aids (scp_dvfs break, usb Charger_Detect_* phy check, gpufreq efuse fallback) are fine as safety nets

## Stage 2+ (NOT done): drivers missing in the 4.19 tree
Config symbols from RMX2020_defconfig that have no Kconfig entry in 4.19 are listed in
RMX2020_PENDING_CONFIG.txt. Directories that still need to be ported from the 4.14 tree:
- drivers/input/touchscreen/oppo_touchscreen (+ nova, ilitek)
- drivers/input/oppo_fp_drivers (egis, silead)
- drivers/soc/oppo, drivers/soc/oplus, drivers/base/power/oppo_pwr_dbg
- charger: oplus charger, bq2589x, bq25910, sy6974
- drivers/misc/mediatek/lcm: ilt9881h_*, nt36525b_*, ilt9882n_* (7 panels)
- imgsensor: sensors live under imgsensor/src/common/v1 in 4.14 but under src/mt6768 in 4.19 (framework differs)
- sound: sia81xx PA

NOT tested: full kernel build, boot, vendor blobs (GPU/camera/modem) against the 4.19 MTK drivers.

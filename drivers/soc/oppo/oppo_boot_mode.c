// SPDX-License-Identifier: GPL-2.0
/*
 * RMX2020 4.19 port: variable declared in mt-plat/mtk_boot_common.h (OPLUS_BUG_STABILITY).
 * In the 4.14 tree it is set by the boot code from the bootloader; here it defaults to normal boot.
 * TODO: parse the bootloader cmdline (silence/safe/aging) if those modes are needed.
 */
#include <linux/export.h>
#include <mt-plat/mtk_boot_common.h>

#ifdef OPLUS_BUG_STABILITY
OPPO_BOOTMODE oppo_boot_mode = OPPO_NORMAL_BOOT;
EXPORT_SYMBOL(oppo_boot_mode);
#endif

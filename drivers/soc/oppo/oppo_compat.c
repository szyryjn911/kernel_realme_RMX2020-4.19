// SPDX-License-Identifier: GPL-2.0
/*
 * RMX2020 4.19 port: oplus globals that the display/fingerprint/battery code references.
 * Their definitions lived in drivers of the 4.14 tree that are not (yet) ported.
 */
#include <linux/export.h>
#include <linux/types.h>
#include <soc/oppo/device_info.h>

/* set to 1 by mtk_disp_mgr on silence boot, read by the fingerprint drivers */
unsigned long oplus_silence_mode;
EXPORT_SYMBOL(oplus_silence_mode);
unsigned int oplus_fp_silence_mode;
EXPORT_SYMBOL(oplus_fp_silence_mode);

/* panels that can send CABC through cmdq set this; default: use the cpu path */
bool oplus_display_cabc_cmdq_support;
EXPORT_SYMBOL(oplus_display_cabc_cmdq_support);

/* battery driver reports its device info; forward it to /proc/devinfo */
void devinfo_info_set(char *name, char *version, char *manufacture)
{
	register_device_proc(name, version, manufacture);
}
EXPORT_SYMBOL(devinfo_info_set);

/*
 * The Xiaomi tcpc drivers in the 4.19 base (tcpc_fusb303.c is always built, tcpc_wusb3801.c too
 * when enabled) declare this as extern but nothing in the tree defines it.
 */
uint8_t typec_cc_orientation;
EXPORT_SYMBOL(typec_cc_orientation);

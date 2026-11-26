// SPDX-License-Identifier: GPL-2.0
/*
 * Weak stand-ins for the oplus/touchscreen symbols referenced by the
 * nt36525b_hlt_hdp_dsi_vdo_lcm panel driver. The real implementations
 * live in the oplus device_info and NT36525B touchscreen drivers of the
 * 4.14 tree; until those are ported these keep the panel linkable, and
 * the real ones override these (weak) when they are added.
 */
#include <linux/compiler.h>
#include <linux/types.h>

int __weak register_device_proc(char *name, char *version, char *manufacture)
{
	return 0;
}

int __weak tp_gesture_enable_flag(void)
{
	return 0;
}

void __weak lcd_queue_load_tp_fw(void)
{
}

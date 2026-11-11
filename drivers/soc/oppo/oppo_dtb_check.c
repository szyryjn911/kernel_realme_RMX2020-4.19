// SPDX-License-Identifier: GPL-2.0
/*
 * RMX2020 4.19 port: print which device tree the kernel is really running with.
 *
 * The 4.19 MTK drivers need properties the 4.14 dts does not have (sspm_mem_key, nvmem-cells for
 * the gpufreq efuse, "phys" for the usb glue). If the bootloader hands the kernel the old 4.14 dtb
 * (e.g. from the boot image's own dtb section) these drivers fail in different places.
 * This runs before any driver probe, so the result is the first thing in the log / pstore console.
 */
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/libfdt.h>
#include <linux/of.h>
#include <linux/of_fdt.h>

static int __init rmx2020_dtb_check(void)
{
	struct device_node *np;
	int sspm_key = 0, nvmem = 0, phys = 0, nodes = 0;

	for_each_of_allnodes(np) {
		nodes++;
		if (of_find_property(np, "sspm_mem_key", NULL))
			sspm_key++;
		if (of_find_property(np, "nvmem-cells", NULL))
			nvmem++;
		if (of_find_property(np, "phys", NULL))
			phys++;
	}

	pr_info("RMX2020 dtb check: fdt %u bytes, %d nodes, sspm_mem_key=%d nvmem-cells=%d phys=%d => %s\n",
		initial_boot_params ? fdt_totalsize(initial_boot_params) : 0,
		nodes, sspm_key, nvmem, phys,
		sspm_key ?
			"4.19 port dtb OK" :
			"LOOKS LIKE THE STOCK 4.14 DTB (the boot image dtb is not the 4.19 one)");
	return 0;
}
early_initcall(rmx2020_dtb_check);

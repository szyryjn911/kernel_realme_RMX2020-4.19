/* SPDX-License-Identifier: GPL-2.0 */
/*
 * Compat shim for the old MTK xlog API (RMX2020 4.19 port).
 * The original implemented __xlog_printk() in the kernel; here it maps to printk().
 */
#ifndef _LINUX_XLOG_H
#define _LINUX_XLOG_H

#include <linux/kernel.h>
#include <linux/linkage.h>

enum android_log_priority {
	ANDROID_LOG_UNKNOWN = 0,
	ANDROID_LOG_DEFAULT,
	ANDROID_LOG_VERBOSE,
	ANDROID_LOG_DEBUG,
	ANDROID_LOG_INFO,
	ANDROID_LOG_WARN,
	ANDROID_LOG_ERROR,
	ANDROID_LOG_FATAL,
	ANDROID_LOG_SILENT,
};

#define xlog_printk(prio, tag, fmt, ...) \
	pr_info("%s: " fmt, tag, ##__VA_ARGS__)
#define xlog_ksystem_printk(prio, tag, fmt, ...) \
	pr_info("%s: " fmt, tag, ##__VA_ARGS__)

#endif /* _LINUX_XLOG_H */

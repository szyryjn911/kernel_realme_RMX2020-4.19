// SPDX-License-Identifier: GPL-2.0
/*
 * Notifier chain used by the oppo LCM/touch drivers to signal a touch firmware update.
 * NOTE: re-implemented for the 4.19 port (declarations: include/linux/update_tpfw_notifier.h).
 */
#include <linux/export.h>
#include <linux/notifier.h>
#include <linux/update_tpfw_notifier.h>

ATOMIC_NOTIFIER_HEAD(tpfw_notifier_list);
EXPORT_SYMBOL(tpfw_notifier_list);

int update_tpfw_register_client(struct notifier_block *nb)
{
	return atomic_notifier_chain_register(&tpfw_notifier_list, nb);
}
EXPORT_SYMBOL(update_tpfw_register_client);

int update_tpfw_unregister_client(struct notifier_block *nb)
{
	return atomic_notifier_chain_unregister(&tpfw_notifier_list, nb);
}
EXPORT_SYMBOL(update_tpfw_unregister_client);

int update_tpfw_notifier_call_chain(unsigned long val, void *v)
{
	return atomic_notifier_call_chain(&tpfw_notifier_list, val, v);
}
EXPORT_SYMBOL(update_tpfw_notifier_call_chain);

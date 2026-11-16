/*
 * Copyright (c) 2017, GlobalLogic Ukraine LLC
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *    This product includes software developed by the GlobalLogic.
 * 4. Neither the name of the GlobalLogic nor the
 *    names of its contributors may be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY GLOBALLOGIC UKRAINE LLC ``AS IS`` AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL GLOBALLOGIC UKRAINE LLC BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#include <linux/init.h>
#include <linux/module.h>
#include <linux/printk.h>
#include <linux/list.h>
#include <linux/ktime.h>
#include <linux/slab.h>

#include "hello1.h"

MODULE_AUTHOR("Serhii Popovych <serhii.popovych@globallogic.com>");
MODULE_AUTHOR("Daria Kopylets <kopylets.daria_io_44@edu.kpi.ua>");
MODULE_DESCRIPTION("Hello, world in Linux Kernel Training: list and timing");
MODULE_LICENSE("Dual BSD/GPL");

struct hello_event {
	struct list_head list;
	ktime_t t_before;
	ktime_t t_after;
};

static LIST_HEAD(hello_list);

int print_hello(void)
{
	struct hello_event *ev;

	ev = kmalloc(sizeof(*ev), GFP_KERNEL);
	if (!ev)
		return -ENOMEM;

	ev->t_before = ktime_get();
	pr_info("Hello, world!\n");
	ev->t_after = ktime_get();

	list_add_tail(&ev->list, &hello_list);
	return 0;
}
EXPORT_SYMBOL(print_hello);

static int __init hello1_init(void)
{
	pr_info("hello1: loaded, print_hello() is exported\n");
	return 0;
}

static void __exit hello1_exit(void)
{
	struct hello_event *ev, *tmp;
	unsigned int n = 0;

	list_for_each_entry_safe(ev, tmp, &hello_list, list) {
		pr_info("hello1: print #%u took %lld ns\n", ++n,
			ktime_to_ns(ktime_sub(ev->t_after, ev->t_before)));
		list_del(&ev->list);
		kfree(ev);
	}
	pr_info("hello1: unloaded, %u events freed\n", n);
}

module_init(hello1_init);
module_exit(hello1_exit);

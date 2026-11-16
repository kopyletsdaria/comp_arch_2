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
#include <linux/moduleparam.h>
#include <linux/printk.h>

#include "hello1.h"

MODULE_AUTHOR("Serhii Popovych <serhii.popovych@globallogic.com>");
MODULE_AUTHOR("Daria Kopylets <kopylets.daria_io_44@edu.kpi.ua>");
MODULE_DESCRIPTION("Hello, world in Linux Kernel Training: user of hello1");
MODULE_LICENSE("Dual BSD/GPL");

static unsigned int count = 1;
module_param(count, uint, 0444);
MODULE_PARM_DESC(count, "How many times to call print_hello() (default 1)");

static int __init hello2_init(void)
{
	unsigned int i;
	int err;

	if (count > 10) {
		pr_err("hello2: count = %u is too big (must be <= 10)\n",
		       count);
		return -EINVAL;
	}

	if (count == 0 || count >= 5)
		pr_warn("hello2: count = %u, continuing anyway\n", count);

	for (i = 0; i < count; i++) {
		err = print_hello();
		if (err)
			return err;
	}

	return 0;
}

static void __exit hello2_exit(void)
{
	pr_info("hello2: unloaded\n");
}

module_init(hello2_init);
module_exit(hello2_exit);

# Лабораторна робота №5. Розроблення модулів Linux Kernel (частина 2)

**Тема:** Розроблення модулів Linux Kernel (частина 2)

**Виконала:** студентка групи ІО-44 Копилець Дар'я

**Перевірив:** Каплунов А.В.

---

**Мета:** ознайомитися з механізмом взаємодії модулів ядра Linux через експортовані символи та отримати практичні навички розділення проєкту на два модулі (hello1, hello2), роботи зі списком, часовими мітками й параметрами модуля та збірки й завантаження модулів у QEMU.

---


## 1. Структура репозиторію

`hello/hello1.c` - список, друк, час, `EXPORT_SYMBOL(print_hello)` 

`hello/hello2.c` - параметр `count`, виклики `print_hello()` 

`hello/inc/hello1.h` - спільний заголовковий файл 

`hello/Makefile`, `hello/Kbuild` - збірка двох модулів, `ccflags-y` для підкаталогу `inc` 

`hello/test_hello.sh` - сценарій `insmod`/`rmmod` з різними параметрами 

`docker-compose.yml`, `setup.sh`, `build.sh` - середовище, залежності, збірка і запуск QEMU 

`rootfs_new.cpio.gz` - коренева ФС із модулями 

`logs/` - журнали `checkpatch`, збірки модулів і тестового запуску 

## 2. Хід роботи

### 2.1. Makefile 

`Makefile`:

```make
ifneq ($(KERNELRELEASE),)
include Kbuild
else
KDIR ?= /lib/modules/`uname -r`/build
default:
    $(MAKE) -C $(KDIR) M=$$PWD
clean:
    $(MAKE) -C $(KDIR) M=$$PWD clean
endif
```

### 2.2. Вихідний код модуля

Ліцензійну шапку (GlobalLogic, з прикладу) збережено у файлі, нижче наведено решту коду.

*hello1.c:*

```c
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

```
*hello2.c:*

```c
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
```

### 2.3. запуск у QEMU

`test_hello.sh`

```sh

#!/bin/sh
EXT=/lib/modules/$(uname -r)/extra
ALL=/tmp/all_messages.log
: > "$ALL"

step() {
    echo
    echo "=================================================="
    echo "### $*"
}

show_dmesg() {
    echo "### dmesg -r:"
    dmesg -r | tee -a "$ALL"
    dmesg -c > /dev/null
}

show_param() {
    if [ -r /sys/module/hello2/parameters/count ]; then
        echo "### /sys/module/hello2/parameters/count = $(cat /sys/module/hello2/parameters/count)"
    fi
}

step "modinfo hello1"
modinfo hello1
step "modinfo hello2"
modinfo hello2

dmesg -c > /dev/null

# hello2 без hello1
step "insmod hello2.ko (hello1 НЕ завантажено)"
insmod $EXT/hello2.ko
echo "### exit code of insmod: $?"
show_dmesg

# hello1, потім hello2 з різними значеннями параметра
step "insmod hello1.ko"
insmod $EXT/hello1.ko
echo "### exit code of insmod: $?"
show_dmesg

for arg in "" "count=0" "count=3" "count=7" "count=11"; do
    step "insmod hello2.ko $arg"
    insmod $EXT/hello2.ko $arg
    echo "### exit code of insmod: $?"
    show_param
    if [ -d /sys/module/hello2 ]; then
        echo "### rmmod hello2"
        rmmod hello2
        echo "### exit code of rmmod: $?"
    fi
    show_dmesg
done

step "insmod hello2.ko count=2, потім спроба rmmod hello1 (поки hello2 завантажено)"
insmod $EXT/hello2.ko count=2
rmmod hello1
echo "### exit code of rmmod hello1: $?"
echo "### lsmod:"
lsmod
rmmod hello2
show_dmesg

step "rmmod hello1 (друк часу кожного виклику print_hello)"
rmmod hello1
echo "### exit code of rmmod: $?"
show_dmesg

step "Пошук повідомлень за рівнями (grep по накопиченому dmesg -r)"
echo "pr_err  (<3>):"; grep '^<3>' "$ALL"
echo "pr_warn (<4>):"; grep '^<4>' "$ALL"
echo "pr_info (<6>), перші 3 з: $(grep -c '^<6>' "$ALL") :"; grep '^<6>' "$ALL" | head -3
```

## 3. Результати
<img width="988" height="499" alt="image" src="https://github.com/user-attachments/assets/073b4d10-de08-4ae4-b06a-1f8d2b5b57e8" />
<img width="1049" height="549" alt="image" src="https://github.com/user-attachments/assets/24d58732-8782-4f62-b65c-b9d173860bdb" />
<img width="741" height="634" alt="image" src="https://github.com/user-attachments/assets/0a260348-f6c0-44b9-8304-4f4a1ad1f3b6" />
<img width="744" height="561" alt="image" src="https://github.com/user-attachments/assets/be3cb16c-91f1-4a1a-8762-1a3a34f36b2c" />
<img width="882" height="456" alt="image" src="https://github.com/user-attachments/assets/683d0fdf-f5fb-46e5-8a43-ccd4b611b6a2" />
<img width="715" height="689" alt="image" src="https://github.com/user-attachments/assets/230a95ee-92b7-49a3-91ea-b88cac3b8600" />
<img width="719" height="344" alt="image" src="https://github.com/user-attachments/assets/b8456ada-2722-4e5c-9dec-5907d7ac1e35" />

## 4. Висновки

При виконанні лабораторної роботи проєкт ЛР4 розділено на два модулі ядра Linux 4.19, які взаємодіють через експортований символ. hello1 інкапсулює список подій і вимірювання часу, hello2 керує кількістю викликів через параметр count. 
Експеримент показав, як працюють залежності модулів: без hello1 модуль hello2 не завантажується, а поки hello2 використовує hello1, вивантажити hello1 неможливо (EBUSY, лічильник у lsmod). depmod фіксує залежність у modules.dep, що дозволяє modprobe підтягувати hello1 автоматично. Усі три рівні повідомлень (pr_err, pr_warn, pr_info) отримано й знайдено через dmesg -r та grep. Час кожного друку, виміряний парою ktime_get() навколо pr_info, виведено при вивантаженні hello1, а пам'ять усіх елементів списку звільнено. Результати вийшли правильними, проблем з виконанням не виникло.



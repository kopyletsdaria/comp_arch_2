# Лабораторна робота №4. Модулі ядра Linux

**Тема:** Модулі ядра Linux

**Виконала:** студентка групи ІО-44 Копилець Дар'я

**Перевірив:** Каплунов А.В.

---

**Мета:** Освоїти практичні навички розробки, збирання, інсталяції та вивантаження модулів ядра Linux у середовищі емуляції QEMU.

---


## 1. Структура репозиторію

 `hello/hello.c`- вихідний код модуля 

 `hello/Makefile`, `hello/Kbuild`- збірка модуля (kbuild, зовнішній модуль) 

 `hello/test_hello.sh` - сценарій `insmod`/`rmmod` з різними параметрами 

 `docker-compose.yml` - контейнер Ubuntu 24.04 для кроскомпіляції 

 `setup.sh` - встановлення залежностей, клонування ядра та BusyBox 

 `build.sh` - збірка ядра, BusyBox, модуля, `rootfs_new.cpio.gz`, запуск QEMU 

 `rootfs_new.cpio.gz` - коренева ФС із модулем `hello.ko` 

 `logs/` - журнали збірки, `checkpatch` і тестового запуску 

## 2. Хід роботи

### 2.1. Середовище

Ядро має бути зібране, щоб були готові файли для компіляції модулів (`Module.symvers`, заголовки, `scripts/`). Перед `make` задаються змінні, потрібні для кросу, зокрема `KDIR` (шлях до каталогу ядра):

```bash
export ARCH=arm
export CROSS_COMPILE=arm-linux-gnueabihf-
export KDIR=/work/src/linux-stable
```

Контейнер піднімається через `docker-compose up -d`, потім `docker exec -it lab4_Kopylets bash`, `bash setup.sh`, `bash build.sh test`.

### 2.2. Makefile і Kbuild

`Makefile` при зовнішньому виклику запускає kbuild ядра (`make -C $(KDIR) M=$$PWD`), а при виклику з боку ядра підключає `Kbuild`:

`Makefile`:

```make
ifneq ($(KERNELRELEASE),)
include Kbuild
else
# normal makefile
KDIR ?= /lib/modules/`uname -r`/build

default:
	$(MAKE) -C $(KDIR) M=$$PWD
clean:
	$(MAKE) -C $(KDIR) M=$$PWD clean
endif
```

`Kbuild`:

```make
# kbuild part of makefile
obj-m := hello.o
```

### 2.3. Вихідний код модуля

Ліцензійну шапку (GlobalLogic, з прикладу) збережено у файлі `hello/hello.c`; нижче наведено решту коду.

```c
#include <linux/init.h>
#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/printk.h>
#include <linux/list.h>
#include <linux/ktime.h>
#include <linux/slab.h>

MODULE_AUTHOR("Serhii Popovych <serhii.popovych@globallogic.com>");
MODULE_AUTHOR("Daria Kopylets <kopylets.daria_io_44@edu.kpi.ua>");
MODULE_DESCRIPTION("Hello, world in Linux Kernel Training");
MODULE_LICENSE("Dual BSD/GPL");

static unsigned int count = 1;
module_param(count, uint, 0444);
MODULE_PARM_DESC(count, "How many times to print \"Hello, world!\" (default 1)");

struct hello_event {
	struct list_head list;
	ktime_t time;
};

static LIST_HEAD(hello_list);

static void hello_free_all(void)
{
	struct hello_event *ev, *tmp;

	list_for_each_entry_safe(ev, tmp, &hello_list, list) {
		pr_info("hello: event time = %lld ns\n", ktime_to_ns(ev->time));
		list_del(&ev->list);
		kfree(ev);
	}
}

static int __init hello_init(void)
{
	struct hello_event *ev;
	unsigned int i;

	if (count > 10) {
		pr_err("hello: count = %u is too big (must be <= 10)\n", count);
		return -EINVAL;
	}

	if (count == 0 || count >= 5)
		pr_warn("hello: count = %u, continuing anyway\n", count);

	for (i = 0; i < count; i++) {
		ev = kmalloc(sizeof(*ev), GFP_KERNEL);
		if (!ev) {
			while (!list_empty(&hello_list)) {
				ev = list_first_entry(&hello_list,
						      struct hello_event, list);
				list_del(&ev->list);
				kfree(ev);
			}
			return -ENOMEM;
		}

		ev->time = ktime_get();
		list_add_tail(&ev->list, &hello_list);

		pr_emerg("Hello, world!\n");
	}

	return 0;
}

static void __exit hello_exit(void)
{
	hello_free_all();
}

module_init(hello_init);
module_exit(hello_exit);
```


### 2.4. Перевірка стилю 

```bash
perl $KDIR/scripts/checkpatch.pl --no-tree -f hello/hello.c
```
<img width="1062" height="62" alt="image" src="https://github.com/user-attachments/assets/cee6625c-d4cf-4196-a776-0759738f0f5b" />

### 2.5. Збірка модуля

```bash
make -C hello
```

<img width="1112" height="442" alt="image-1" src="https://github.com/user-attachments/assets/7e158531-a718-4f5c-8905-767f77c2f856" />

### 2.6. запуск у QEMU

`test_hello.sh`

```sh

#!/bin/sh

MOD=${MOD:-/lib/modules/$(uname -r)/extra/hello.ko}

run_case() {
	echo
	echo "=================================================="
	echo "### insmod hello.ko $*"
	dmesg -c > /dev/null
	insmod "$MOD" "$@"
	rc=$?
	echo "### exit code of insmod: $rc"
	if [ -r /sys/module/hello/parameters/count ]; then
		echo "### /sys/module/hello/parameters/count = $(cat /sys/module/hello/parameters/count)"
		echo "### rmmod hello"
		rmmod hello
		echo "### exit code of rmmod: $?"
	else
		echo "### module is not loaded (nothing to rmmod)"
	fi
	echo "### dmesg:"
	dmesg
}

echo "### modinfo hello"
modinfo hello

run_case                
run_case count=0        
run_case count=3        
run_case count=7       
run_case count=10      
run_case count=11      

```

## 3. Результати

### 3.1. modinfo

<img width="947" height="211" alt="image-2" src="https://github.com/user-attachments/assets/b8431ba9-6c3f-46df-8ca0-418422e9d206" />

### 3.2. Запуск: без параметра (значення за замовчуванням)

<img width="881" height="305" alt="image-3" src="https://github.com/user-attachments/assets/84ca42fb-d8a0-4e20-9476-561f85e52bb8" />

### 3.3. Запуск:  bash /project/build.sh test

<img width="707" height="951" alt="image-4" src="https://github.com/user-attachments/assets/b0ee30ee-2548-431f-aa2a-350b4e55ca82" />

<img width="658" height="906" alt="image-6" src="https://github.com/user-attachments/assets/000c6ad9-9679-48e7-9ccd-a8e2dc686036" />

<img width="962" height="955" alt="image-7" src="https://github.com/user-attachments/assets/274aeaa7-64aa-4f85-b684-d37c65f1c07e" />

<img width="736" height="115" alt="image-8" src="https://github.com/user-attachments/assets/9145b64a-c7db-46a1-bec1-1b27bf09e9df" />

## 4. Висновки

У роботі створено завантажуваний модуль ядра Linux 4.19 для ARM, зібраний зовнішньою системою kbuild (`Makefile` + `Kbuild`). Модуль приймає параметр `count`, перевіряє його значення (попередження для 0 і 5..10, помилка `-EINVAL` для значень понад 10), виводить опис параметра через `modinfo` і показує поточне значення. Тестування в QEMU підтвердило очікувану поведінку для всіх діапазонів значень параметра.

### BIG FAT WARNING

> Flashing your router is a always risky procedure. You're doing it at your own risk, you take the full responsibility
> for any action you choose, we cannot be held liable for any damage you do to your device, other devices, any other
> person or animal.

### Purpose

Easier flashing of OpenWrt firmware on UBNT M2HP (and maybe others?) devices running airOS v6 and higher.

### License

[mtd](https://archive.openwrt.org/kamikaze/8.09.2/ar71xx/packages/mtd_8.2_mips.ipk) utility shipped in
[flash.sh](https://github.com/true-systems/ubnt-bullet-m2hp-openwrt-flashing/blob/master/flash.sh) is licensed under
GPLv2, everything else in this repository [is free and unencumbered software released into the public
domain.](http://unlicense.org)

### Usage

1. You need to flash your UBNT M2HP with [airOS v6.1.7 firmware](https://dl.ubnt.com/firmwares/XW-fw/v6.1.7/XW.v6.1.7.32555.180523.1754.bin) no other airOS version is supported

2. Download this toolkit sources
```
git clone https://github.com/true-systems/ubnt-bullet-m2hp-openwrt-flashing
cd ubnt-bullet-m2hp-openwrt-flashing
```

3. Flash OpenWrt
```
make flash FW_UBNT=/path/to/your/openwrt-ath79-generic-ubnt_bullet-m2hp-squashfs-sysupgrade.bin
```

### Background

It's not possible to use `fwupdate.real` utility for flashing OpenWrt to UBNT devices anymore as it allows flashing of
signed firmware images only:

```
XW.v6.1.7# fwupdate.real -m /tmp/openwrt-ath79-generic-ubnt_bullet-m2hp-squashfs-factory.bin  -d
Found mtd block: /dev/mtd0(u-boot)
Found mtd block: /dev/mtd1(u-boot-env)
Found mtd block: /dev/mtd2(kernel)
Found mtd block: /dev/mtd3(rootfs)
Found mtd block: /dev/mtd4(cfg)
Found mtd block: /dev/mtd5(EEPROM)
Got U-Boot variable: mtdparts = mtdparts=ath-nor0:256k(u-boot),64k(u-boot-env),1024k(kernel),6528k(rootfs),256k(cfg),64k(EEPROM)
Adding U-Boot partition: u-boot 9F000000 00040000
Adding U-Boot partition: u-boot-env 9F040000 00010000
Adding U-Boot partition: kernel 9F050000 00100000
Adding U-Boot partition: rootfs 9F150000 00660000
Adding U-Boot partition: cfg 9F7B0000 00040000
Adding U-Boot partition: EEPROM 9F7F0000 00010000
Calculating flash size:
Adding block: /dev/mtd0("u-boot") - size: 00040000
Adding block: /dev/mtd1("u-boot-env") - size: 00010000
Adding block: /dev/mtd2("kernel") - size: 00100000
Adding block: /dev/mtd3("rootfs") - size: 00660000
Adding block: /dev/mtd4("cfg") - size: 00040000
Adding block: /dev/mtd5("EEPROM") - size: 00010000
Total flash size: 00800000
Flash start: 9F000000
Flash end: 9F800000
Header MAGIC 'OPEN'
Current: XW.ar934x.v6.1.7.32555.180523.1754

New ver: XW.ar934x.v6.0.4-OpenWrt-r8452+9-e95e9fc
Versions: New(393220) 6.0.4, Required(393220) 6.0.4
FW Part: "kernel"(1), MAGIC: 'PART', Base: 0x9F050000, DLen: 0x00100000, PLen: 0x00100000
FW Part: "rootfs"(2), MAGIC: 'PART', Base: 0x9F150000, DLen: 0x00280004, PLen: 0x00660000
Bad Image Structure
Signature check failed
```

So we're left with probably these remaining options:

* dissassemble and patch `fwupdate.real` utility so it would accept and flash unsigned OpenWrt firmware images
  * this needs someone more skilled as I'm currently not able to dissassemble `ubntbox` binary even with latest radare2
    so the output is usable/readable, the problem is probably very old toolchain and uClibc
* solder serial console and use TFTP for image flashing using `tftpboot` with initramfs image
* try to flash sysupgrade image using `mtd` over ssh in airOS

### Flashing sysupgrade image using `mtd` over ssh in airOS v6.1.7

This approach is using [`mtd` utility from Kamikaze 8.09.2](https://archive.openwrt.org/kamikaze/8.09.2/ar71xx/packages/mtd_8.2_mips.ipk)
for flashing OpenWrt sysupgrade image. Unfortunately this is not so easy either, as there seems to be some flash write
lock protection in place, kernel is probably expecting some secret cookie, before it would allow writing to MTD flash:

```
XW.v6.1.7# dd if=/dev/zero of=/tmp/kernel bs=$((0x100000)) count=1

XW.v6.1.7# /tmp/mtd write /tmp/kernel kernel
Unlocking kernel ... 
Writing from /tmp/kernel to kernel ...    

XW.v6.1.7# md5sum /tmp/kernel 
b6d81b360a5672d80c27430f39153e2c  /tmp/kernel

XW.v6.1.7# md5sum /dev/mtd2
30c85e4d3c1a88c566d83678055025b9  /dev/mtd2
```

And it seems that `fwupdate.real` utility is able to unlock this flash
protection, so as a workaround (until proper fix) we can simply initiate
flashing of the factory v6.1.7 firmware image and interrupt it during the 
flashing process:

```
XW.v6.1.7# fwupdate.real -m /tmp/XW.v6.1.7.32555.180523.1754.bin -d
Found mtd block: /dev/mtd0(u-boot)
... 
Block on '/dev/mtd3' at 00060000(len: 00010000) has no changes.
[%7  ]
^C
```

Now the flash should be unlocked. Then we just need to solve missing `firmware` partition in the airOS firmware, but
this is doable as we can split the sysupgrade image to `kernel` and `rootfs` parts:

```
XW.v6.1.7# cat /proc/mtd
dev:    size   erasesize  name
mtd0: 00040000 00010000 "u-boot"
mtd1: 00010000 00010000 "u-boot-env"
mtd2: 00100000 00010000 "kernel"
mtd3: 00660000 00010000 "rootfs"
mtd4: 00040000 00010000 "cfg"
mtd5: 00010000 00010000 "EEPROM"

```

Flashing part of the sysupgrade image to the `kernel` partition and the rest of the image to `rootfs`:

```
CI_BLKSZ=65536
fw="/tmp/openwrt-ath79-generic-ubnt_bullet-m2hp-squashfs-sysupgrade.bin"
rootfs_size=0x$(grep rootfs /proc/mtd | cut -d ' ' -f2)
kernel_size=0x$(grep kernel /proc/mtd | cut -d ' ' -f2)
kernel_blocks=$(($kernel_size / $CI_BLKSZ))

dd if="$fw" bs=$CI_BLKSZ count=$kernel_blocks 2>/dev/null | /tmp/mtd -e kernel write - kernel
dd if="$fw" bs=$CI_BLKSZ skip=$kernel_blocks 2>/dev/null | /tmp/mtd -r -e rootfs write - rootfs
```

You can do all this steps manually or just use content of this repository for [more automated process](#usage).

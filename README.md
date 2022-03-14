# BIG FAT WARNING

> Flashing your router is always risky procedure. You're doing it at your own risk, you take the full responsibility
> for any action you choose, we cannot be held liable for any damage you do to your device, other devices, any other
> person or animal.

### Purpose

Easier end-user flashing (no soldering needed) of OpenWrt firmware on UBNT M2HP [(and maybe others?)](#supported-and-tested-devices) devices running airOS v6.1.7. 

### License

[mtd](https://archive.openwrt.org/kamikaze/8.09.2/ar71xx/packages/mtd_8.2_mips.ipk) utility shipped in
[flash-sysupgrade.sh](https://github.com/true-systems/ubnt-bullet-m2hp-openwrt-flashing/blob/master/flash-sysupgrade.sh) is licensed under
GPLv2, everything else in this repository [is free and unencumbered software released into the public
domain.](http://unlicense.org)

### Tested device list

|   Device      |   Status     |   Factory    |   Sysupgrade |
|:-------------:|:------------:|:------------:|:------------:|
| [Bullet M2HP](https://www.ubnt.com/airmax/bulletm/#specs)  | `Working`    |     Yes      |     Yes      |
| [PowerBeam M5-400](https://openwrt.org/toh/hwdata/ubiquiti/ubiquiti_powerbeam_m5-400) | `Working` | No | Yes |
| [PowerBeam M5-400](https://openwrt.org/toh/hwdata/ubiquiti/ubiquiti_powerbeam_m5-400) | `Working` | No | Yes |
| [Nanostation Loco M2 (xw)](https://openwrt.org/toh/ubiquiti/nanostationm2) | `Working` | No | Yes |

We currently have access to just one type of device so can't confirm if similar approach might work on other devices with same airOS version. Feel free to test it and let us know.


### Usage
#### Prerequisites

1. You need to flash your UBNT M2HP with [airOS v6.1.7 firmware](https://dl.ubnt.com/firmwares/XW-fw/v6.1.7/XW.v6.1.7.32555.180523.1754.bin)
   no other airOS version is currently supported

2. Download this toolkit sources
```
git clone https://github.com/true-systems/ubnt-bullet-m2hp-openwrt-flashing
cd ubnt-bullet-m2hp-openwrt-flashing
```
#### Flashing OpenWrt sysupgrade image

You can find [more details](#flashing-sysupgrade-image-using-mtd-over-ssh-in-airos-v617) about this method bellow.
```
make flash-sysupgrade FW_OWRT=/path/to/your/openwrt-ath79-generic-ubnt_bullet-m2hp-squashfs-sysupgrade.bin
```

#### Flashing OpenWrt factory image

You can find [more details](#flashing-factory-image-using-patched-fwupdatereal-command-over-ssh-in-airos-v617) about this method bellow.

```
make flash-factory FW_OWRT=/path/to/your/openwrt-ath79-generic-ubnt_bullet-m2hp-squashfs-factory.bin
```

Example output from successful flashing sessions:

* Flashing factory image in [flash-factory.log](https://raw.githubusercontent.com/true-systems/ubnt-bullet-m2hp-openwrt-flashing/master/flash-factory.log).
* Flashing sysupgrade image in [flash-sysupgrade.log](https://raw.githubusercontent.com/true-systems/ubnt-bullet-m2hp-openwrt-flashing/master/flash-sysupgrade.log).

#### Other useful make targets

##### Get patched `fwupdate.real` command

For legal reasons, we can't redistribute patched binaries. To get patched `fwupdate.real` command with removed RSA image signature checking directly from your router with default IP address `192.168.1.20` use following commands.

```
make ubntbox.patched REMOTE_UBNT=ubnt@192.168.1.20
mv ubntbox.patched fwupdate.real
```

##### Restore from OpenWrt back to factory image

Before running every flash command, we create backup of currently running factory firmware image in `firmware-backup.bin`. You can then restore your router running OpenWrt with `192.168.1.1` IP address back to this firmware by using this `make` target.
```
make restore REMOTE_OWRT=root@192.168.1.1
```

### Background

It's not possible to use `fwupdate.real` utility for flashing OpenWrt to UBNT devices anymore as it allows flashing of
signed firmware images only:

```
XW.v6.1.7# fwupdate.real -m /tmp/openwrt-ath79-generic-ubnt_bullet-m2hp-squashfs-factory.bin  -d
...
Current: XW.ar934x.v6.1.7.32555.180523.1754

New ver: XW.ar934x.v6.0.4-OpenWrt-r8452+9-e95e9fc
Versions: New(393220) 6.0.4, Required(393220) 6.0.4
FW Part: "kernel"(1), MAGIC: 'PART', Base: 0x9F050000, DLen: 0x00100000, PLen: 0x00100000
FW Part: "rootfs"(2), MAGIC: 'PART', Base: 0x9F150000, DLen: 0x00280004, PLen: 0x00660000
Bad Image Structure
Signature check failed
```

So we were left with probably these remaining flashing methods:

* solder serial console and use TFTP for image flashing using `tftpboot` with initramfs image
* try to flash sysupgrade image using `mtd` over SSH in airOS
* dissassemble and patch `fwupdate.real` command so it would accept and flash unsigned OpenWrt factory firmware images

For end users, it's always more convenient to find some flashing method which
wouldn't involve any soldering, so we've first tried to find out if it would be
possible to flash OpenWrt with `mtd` over SSH in airOS. We've found out that
it's doable.

Then just out of the curiosity and for some fun, we've tried to patch out RSA
signature checking from `fwupdate.real` utility and check if it would allow us
flashing unsigned factory firmware image generated by OpenWrt. We've found out,
that it's doable also.

You can read more details about those two methods in more detail bellow.

### Flashing factory image using patched `fwupdate.real` command over SSH in airOS v6.1.7

This approach is using patched `fwupdate.real` command from `ubntbox` utility.
We've simply removed `Bad Image Structure` and `Signature check failed` checks,
so it's now possible to flash factory images built with OpenWrt.

`radiff2` with JSON output shows what was patched out in `ubntbox.patched`:

```
r2@6608438f7a41:~$ radiff2 -j /data/ubntbox /data/ubntbox.patched 

{"files":[{"filename":"/data/ubntbox", "size":715136, "sha256":"73460d7205549e1298fd0dad718edd61d06b8db07aecc637a41cbb547630e587"},
{"filename":"/data/ubntbox.patched", "size":715136, "sha256":"ca06d93741b30bdcb3a8b0577545aa0c32c4b5d9ac88f8580bae5a2774c890c3"}],
"changes":[{"offset":57104,"from":"16e0", "to":"0000"},
{"offset":57107,"from":"038f9982", "to":"00000000"},
{"offset":57112,"from":"10", "to":"00"},
{"offset":57115,"from":"772410ff2d92e4", "to":"00000000000000"},
{"offset":57123,"from":"1402e420212484", "to":"00000000000000"},
{"offset":57131,"from":"3803c028210320f809", "to":"000000000000000000"},
{"offset":57141,"from":"9e30231040", "to":"0000000000"},
{"offset":57147,"from":"0a8fbc", "to":"000000"},
{"offset":57151,"from":"288f8283f88f8480288f99814c8c45", "to":"000000000000000000000000000000"},
{"offset":57168,"from":"0320f80924846d148fbc", "to":"00000000000000000000"},
{"offset":57179,"from":"2810", "to":"0000"},
{"offset":57183,"from":"662410ff2c", "to":"0000000000"},
{"offset":60576,"from":"16f1fc878f848028", "to":"0000000000000000"}]
```

Unfortunately we can't redistribute patched `ubntbox.patched` binary, but you
can get patched `ubntbox` from your router by just running `make ubntbox.patched` command.
You can find output from flashing session of factory image with patched `ubntbox.patched` in [flash-factory.log](https://raw.githubusercontent.com/true-systems/ubnt-bullet-m2hp-openwrt-flashing/master/flash-factory.log).

### Flashing sysupgrade image using `mtd` over SSH in airOS v6.1.7

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
You can find complete output from flashing session of sysupgrade image with `make flash-sysupgrade` command using above explained approach in [flash-sysupgrade.log](https://raw.githubusercontent.com/true-systems/ubnt-bullet-m2hp-openwrt-flashing/master/flash-sysupgrade.log).

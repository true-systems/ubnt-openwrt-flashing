#!/bin/sh
# vim: ts=4 sts=4 sw=4 noet

echo "FIXME, not working yet, but you can try 'make flash-factory' instead"; exit 1

# FIXME: Need to find out different patching method as dd on airOS
# doesn't support conv option
nop() {
	dd if=/dev/zero bs=1 count=$3 | \
		dd of=$1 bs=1 count=$3 seek=$2 conv=notrunc 2> /dev/null
}

patch_ubntbox() {
	local ubntbox="/sbin/ubntbox"
	local fwupdate="/tmp/fwupdate.real"
	local md5_patched="57946077ad228ea93067ce9ee980afb6"
	local md5_unpatched="6f7d535db287794ca7e13158f80f1ef3"

	local unpatched=$(md5sum $ubntbox) && unpatched="${unpatched%% *}"
	[ $unpatched = $md5_unpatched ] || {
		echo "Unable to patch $ubntbox ($unpatched)"; exit 1
	}

	echo "Removing RSA signature checking in $fwupdate"

	cp $ubntbox $fwupdate
	nop $fwupdate 57104 2
	nop $fwupdate 57107 4
	nop $fwupdate 57112 1
	nop $fwupdate 57115 7
	nop $fwupdate 57123 7
	nop $fwupdate 57131 9
	nop $fwupdate 57141 5
	nop $fwupdate 57147 3
	nop $fwupdate 57151 1
	nop $fwupdate 57168 1
	nop $fwupdate 57179 2
	nop $fwupdate 57183 5
	nop $fwupdate 60576 8

	local patched=$(md5sum $fwupdate) && patched="${patched%% *}"
	[ $patched = $md5_patched ] || {
		echo "Patching $fwupdate failed ($patched)"; exit 1
	}

	echo "Patching, done!"
}

flash_factory() {
	local fw="$1"
	[ -e "$fw" ] || {
		echo "No such file: $fw, did you forget to upload it?"; exit 1
	}

	local image_magic=$(dd if="$fw" bs=13 count=1 2> /dev/null)
	[ $image_magic = "OPENXW.ar934x" ] || {
		echo "Only OpenWrt factory firmware image for ubnt-xw ar934x platform is supported"; exit 1
	}

	echo "Flashing factory image, good luck!"
	# /tmp/fwupdate.real -m "$fw" -d
}

[ -n "$1" ] || {
	echo "Usage: $0 openwrt-factory-image.bin"
	exit 1
}

patch_ubntbox
flash_factory "$1"

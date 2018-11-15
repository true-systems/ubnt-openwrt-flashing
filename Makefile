REMOTE_UBNT ?= ubnt@192.168.1.20
REMOTE_OWRT ?= root@192.168.1.175
FW_BACKUP ?= firmware-backup.bin
FW_OWRT ?= openwrt-ath79-generic-ubnt_bullet-m2hp-squashfs-sysupgrade.bin
FW_UBNT ?= XW.v6.1.7.32555.180523.1754.bin

all:
	@echo "Usage: `make flash` or `make restore`"

$(FW_UBNT):
	wget https://dl.ubnt.com/firmwares/XW-fw/v6.1.7/$(FW_UBNT)

$(FW_BACKUP):
	@echo "You first need to have a firmware backup!"; exit 1

# Flashing OpenWrt over airOS v6.1.7
flash: $(FW_UBNT)
	ssh-copy-id $(REMOTE_UBNT)
	@echo "Creating factory firmware backup"
	ssh $(REMOTE_UBNT) "cat /dev/mtd2 /dev/mtd3" > $(FW_BACKUP)
	ssh $(REMOTE_UBNT) "mount -t tmpfs tmpfs /tmp"
	scp flash.sh $(FW_OWRT) $(FW_UBNT) $(REMOTE_UBNT):/tmp
	ssh $(REMOTE_UBNT) "/bin/sh /tmp/flash.sh 2>&1" | tee flash.log

# Restoring airOS backup over OpenWrt
restore: $(FW_BACKUP)
	scp $(FW_BACKUP) $(REMOTE_OWRT):/tmp
	ssh $(REMOTE_OWRT) "mtd -r write /tmp/$(FW_BACKUP) firmware 2>&1" | tee restore.log

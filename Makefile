SHELL=bash

REMOTE_UBNT ?= ubnt@192.168.1.20
REMOTE_OWRT ?= root@192.168.1.175
FW_BACKUP ?= firmware-backup.bin
FW_OWRT ?= openwrt-ath79-generic-ubnt_bullet-m2hp-squashfs-sysupgrade.bin
FW_UBNT ?= XW.v6.1.7.32555.180523.1754.bin
UBNTBOX ?= ubntbox
UBNTBOX_PATCHED ?= $(UBNTBOX).patched

# Starting with OpenSSH v9.0, scp requires the -O option to use the legacy SCP protocol
SCP_LEGACY_ARG := $(shell scp 2>&1 | grep -q O && echo -O)

all:
	@echo 'Please read carefully README.md'

$(FW_UBNT):
	wget https://dl.ubnt.com/firmwares/XW-fw/v6.1.7/$(FW_UBNT)

$(FW_BACKUP):
	@echo "You first need to have a firmware backup!"; exit 1

# $(1): input file
# $(2): offset
# $(3): count
define nopout
  (dd if=/dev/zero bs=1 count=$(3) | dd of=$(1) bs=1 count=$(3) seek=$(2) conv=notrunc) 2> /dev/null
endef

$(UBNTBOX):
	scp $(SCP_LEGACY_ARG) $(REMOTE_UBNT):/sbin/$(UBNTBOX) $(UBNTBOX)
	@sha256sum -c $(UBNTBOX).sha256sum > /dev/null

$(UBNTBOX_PATCHED): $(UBNTBOX) FORCE
	@cp $(UBNTBOX) $(UBNTBOX_PATCHED)
	@$(call nopout,$@,57104,2)
	@$(call nopout,$@,57107,4)
	@$(call nopout,$@,57112,1)
	@$(call nopout,$@,57115,7)
	@$(call nopout,$@,57123,7)
	@$(call nopout,$@,57131,9)
	@$(call nopout,$@,57141,5)
	@$(call nopout,$@,57147,3)
	@$(call nopout,$@,57151,15)
	@$(call nopout,$@,57168,10)
	@$(call nopout,$@,57179,2)
	@$(call nopout,$@,57183,5)
	@$(call nopout,$@,60576,8)
	@sha256sum -c $(UBNTBOX_PATCHED).sha256sum > /dev/null

# Flashing OpenWrt factory image over airOS v6.1.7
flash-factory: $(UBNTBOX_PATCHED)
	ssh-copy-id $(REMOTE_UBNT)
	@echo "Creating factory firmware backup"
	ssh $(REMOTE_UBNT) "cat /dev/mtd2 /dev/mtd3" > $(FW_BACKUP)
	ssh $(REMOTE_UBNT) "umount /tmp; mount -t tmpfs tmpfs /tmp"
	scp $(SCP_LEGACY_ARG) $(UBNTBOX_PATCHED) $(REMOTE_UBNT):/tmp/fwupdate.real
	scp $(SCP_LEGACY_ARG) $(FW_OWRT) $(REMOTE_UBNT):/tmp
	ssh $(REMOTE_UBNT) "/tmp/fwupdate.real -m /tmp/$(notdir $(FW_OWRT)) -d 2>&1" | tee $@.log

# Flashing OpenWrt sysupgrade image over airOS v6.1.7
flash-sysupgrade: $(FW_UBNT)
	ssh-copy-id $(REMOTE_UBNT)
	@echo "Creating factory firmware backup"
	ssh $(REMOTE_UBNT) "cat /dev/mtd2 /dev/mtd3" > $(FW_BACKUP)
	ssh $(REMOTE_UBNT) "umount /tmp ;mount -t tmpfs tmpfs /tmp"
	scp $(SCP_LEGACY_ARG) $@.sh $(FW_OWRT) $(FW_UBNT) $(REMOTE_UBNT):/tmp
	ssh $(REMOTE_UBNT) "/bin/sh /tmp/$@.sh /tmp/$(notdir $(FW_OWRT)) 2>&1" | tee $@.log

# Restoring airOS backup over OpenWrt
restore: $(FW_BACKUP)
	scp $(SCP_LEGACY_ARG) $(FW_BACKUP) $(REMOTE_OWRT):/tmp
	ssh $(REMOTE_OWRT) "mtd -r write /tmp/$(FW_BACKUP) firmware 2>&1" | tee $@.log

clean:
	@-rm $(UBNTBOX) $(UBNTBOX_PATCHED) 2> /dev/null

FORCE: ;
.PHONY: all restore FORCE

# VM config
VM_NAME := 'Personal Fedora'
MEMORY := 4096
VCPUS := 4

# ISO config
BASE_ISO_PATH := ./Fedora-Everything-netinst-x86_64-43-1.6.iso
PERSONAL_ISO_NAME := Fedora-43-Personal-x86_64.iso
ISO_DIST_DIR := ./dist
PERSONAL_ISO_PATH := ${ISO_DIST_DIR}/${PERSONAL_ISO_NAME}
VOLID := Fedora_P_x86_64
BOOT := uefi # {bios|uefi}

# Project structure
SRC_DIR := ./src
TMP_DIR := ./tmp
MOUNT_DIR := ./base-iso

# Kickstart information
USER = $(shell grep -E '^USER=' ./config | cut -d= -f2)
ROOT_PASSWD = $(shell grep -E '^ROOT_PASSWD=' ./.secrets | cut -d= -f2)
USER_PASSWD = $(shell grep -E '^USER_PASSWD=' ./.secrets | cut -d= -f2)
MOKUTIL_PASSWD = $(shell grep -E '^MOKUTIL_PASSWD=' ./.secrets | cut -d= -f2)

.PHONY: install_os destroy_vm clean build

build: ${PERSONAL_ISO_PATH}
${PERSONAL_ISO_PATH}: ${BASE_ISO_PATH} ${ISO_DIST_DIR} ${TMP_DIR}/tmp_grub.cfg ${TMP_DIR}/tmp_kickstart.cfg $(wildcard ${SRC_DIR}/bin/*)
	if [[ -f ${PERSONAL_ISO_PATH} ]]; then \
		rm ${PERSONAL_ISO_PATH}; \
	fi

	if ! mountpoint -q ${MOUNT_DIR}; then \
		mkdir -p ${MOUNT_DIR}; \
		osirrox -indev ${BASE_ISO_PATH} -extract / ${MOUNT_DIR}; \
	fi
	cp ${TMP_DIR}/tmp_kickstart.cfg ${MOUNT_DIR}/kickstart.cfg
	cp ${TMP_DIR}/tmp_grub.cfg ${MOUNT_DIR}/boot/grub2/grub.cfg
	cp ${TMP_DIR}/tmp_grub.cfg ${MOUNT_DIR}/EFI/BOOT/grub.cfg
	cp -r ${SRC_DIR}/bin ${MOUNT_DIR}
	rsync -a ${SRC_DIR}/dots-hyprland ${MOUNT_DIR}

	sed -i 's/@@@MOKUTIL_PASSWD@@@/${MOKUTIL_PASSWD}/' ${MOUNT_DIR}/bin/post_install.sh

	xorriso -as mkisofs \
		-o ${PERSONAL_ISO_PATH} \
		-volid "${VOLID}" \
		--grub2-mbr --interval:local_fs:0s-15s:zero_mbrpt,zero_gpt:'Fedora-Everything-netinst-x86_64-43-1.6.iso' \
		--protective-msdos-label \
		-partition_cyl_align off \
		-partition_offset 16 \
		-append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b \
		--interval:local_fs:2262972d-2288803d::'Fedora-Everything-netinst-x86_64-43-1.6.iso' \
		-appended_part_as_gpt \
		-iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
		--boot-catalog-hide \
		-b '/images/eltorito.img' \
		-no-emul-boot \
		-boot-load-size 4 \
		-boot-info-table \
		--grub2-boot-info \
		-eltorito-alt-boot \
		-e '--interval:appended_partition_2_start_565743s_size_25832d:all::' \
		-no-emul-boot \
		-boot-load-size 25832 \
		./base-iso/


install_os: destroy_vm ${PERSONAL_ISO_PATH}
	virt-install \
		--name ${VM_NAME} \
		--memory ${MEMORY} \
		--vcpus ${VCPUS} \
		--disk path=${ISO_DIST_DIR}/fedora.qcow2,size=40,format=qcow2 \
		--virt-type kvm \
		--cdrom ${PERSONAL_ISO_PATH} \
		--os-variant fedora-unknown \
		--boot ${BOOT} \
		--check path_in_use=off

load_os: destroy_vm ${ISO_DIST_DIR}/fedora.qcow2
	virt-install \
		--import \
		--name ${VM_NAME} \
		--memory ${MEMORY} \
		--vcpus ${VCPUS} \
		--disk path=${ISO_DIST_DIR}/fedora.qcow2,format=qcow2 \
		--virt-type kvm \
		--os-variant fedora-unknown \
		--boot ${BOOT} \
		--check path_in_use=off

destroy_vm:
	if virsh list | grep ${VM_NAME}; then \
		virsh shutdown ${VM_NAME}; \
		virsh destroy ${VM_NAME}; \
		virsh undefine ${VM_NAME} --managed-save --nvram; \
	fi


${BASE_ISO_PATH}:
	curl -L -O https://download.fedoraproject.org/pub/fedora/linux/releases/43/Everything/x86_64/iso/Fedora-Everything-netinst-x86_64-43-1.6.iso

${ISO_DIST_DIR}:
	mkdir -p ${ISO_DIST_DIR}

${SRC_DIR}:
	mkdir -p ${SRC_DIR}

${TMP_DIR}:
	mkdir -p ${TMP_DIR}

${TMP_DIR}/tmp_kickstart.cfg: ${TMP_DIR} ${SRC_DIR}/kickstart.cfg ${SRC_DIR}/packages.lst
	cp ${SRC_DIR}/kickstart.cfg ${TMP_DIR}/tmp_kickstart.cfg
	cat ${SRC_DIR}/packages.lst >> ${TMP_DIR}/tmp_kickstart.cfg
	echo '%end' >> ${TMP_DIR}/tmp_kickstart.cfg

	sed -i 's|@@@USER@@@|${USER}|g' ${TMP_DIR}/tmp_kickstart.cfg
	sed -i 's|@@@ROOT_PASSWD@@@|${ROOT_PASSWD}|g' ${TMP_DIR}/tmp_kickstart.cfg
	sed -i 's|@@@USER_PASSWD@@@|${USER_PASSWD}|g' ${TMP_DIR}/tmp_kickstart.cfg

${TMP_DIR}/tmp_grub.cfg: ${TMP_DIR} ${SRC_DIR}/grub.cfg
	cp ${SRC_DIR}/grub.cfg ${TMP_DIR}/tmp_grub.cfg
	sed -i 's/@@@VOLID@@@/${VOLID}/g' ${TMP_DIR}/tmp_grub.cfg

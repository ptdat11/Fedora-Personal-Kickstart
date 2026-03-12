# VM config
VM_NAME := 'Personal Fedora'
MEMORY := 4096
VCPUS := 4

# ISO config
BASE_ISO_PATH := ./Fedora-Everything-netinst-x86_64-43-1.6.iso
PERSONAL_ISO_NAME := Fedora-43-Personal-x86_64.iso
ISO_DIST_DIR := ./dist
PERSONAL_ISO_PATH := ${ISO_DIST_DIR}/${PERSONAL_ISO_NAME}
VOLID := Fedora_43_P_x86_64

# Project structure
SRC_DIR := ./src
TMP_DIR := ./tmp

# Kickstart information
ROOT_PASSWD = $(shell grep -E '^ROOT_PASSWD=' ./.secrets | cut -d= -f2)
USER_PASSWD = $(shell grep -E '^USER_PASSWD=' ./.secrets | cut -d= -f2)

.PHONY: install_os destroy_vm clean build

build: ${BASE_ISO_PATH} ${ISO_DIST_DIR} ${TMP_DIR}/tmp_grub.cfg ${TMP_DIR}/tmp_kickstart.cfg $(wildcard ${SRC_DIR}/bin/*)
	if [[ -f ${PERSONAL_ISO_PATH} ]]; then \
		rm ${PERSONAL_ISO_PATH}; \
	fi

	xorriso -indev ${BASE_ISO_PATH} \
		-outdev ${PERSONAL_ISO_PATH} \
		-volid ${VOLID} \
		-compliance no_emul_toc \
		-map ${TMP_DIR}/tmp_kickstart.cfg /kickstart.cfg \
		-map ${TMP_DIR}/tmp_grub.cfg /boot/grub2/grub.cfg \
		-map ${SRC_DIR}/bin /bin \
		-boot_image any replay


install_os: destroy_vm build
	virt-install \
		--name ${VM_NAME} \
		--memory ${MEMORY} \
		--vcpus ${VCPUS} \
		--disk path=${ISO_DIST_DIR}/fedora.qcow2,size=40,format=qcow2 \
		--virt-type kvm \
		--cdrom ${PERSONAL_ISO_PATH} \
		--os-variant fedora-unknown \
		--boot uefi \
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
		--boot uefi \
		--check path_in_use=off

destroy_vm:
	if virsh list | grep ${VM_NAME}; then \
		virsh shutdown ${VM_NAME}; \
		virsh destroy ${VM_NAME}; \
		virsh undefine ${VM_NAME}; \
	fi


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

	sed -i 's|@@@ROOT_PASSWD@@@|${ROOT_PASSWD}|' ${TMP_DIR}/tmp_kickstart.cfg
	sed -i 's|@@@USER_PASSWD@@@|${USER_PASSWD}|' ${TMP_DIR}/tmp_kickstart.cfg

${TMP_DIR}/tmp_grub.cfg: ${TMP_DIR} ${SRC_DIR}/grub.cfg
	cp ${SRC_DIR}/grub.cfg ${TMP_DIR}/tmp_grub.cfg
	sed -i 's/@@@VOLID@@@/${VOLID}/g' ${TMP_DIR}/tmp_grub.cfg

VM_NAME := custom_fedora

# ISO information
BASE_ISO_PATH := ./Fedora-Everything-netinst-x86_64-43-1.6.iso
CUSTOM_ISO_NAME := Fedora-43-Personal-x86_64.iso
ISO_DIST_DIR := ./dist
CUSTOM_ISO_PATH := ${ISO_DIST_DIR}/${CUSTOM_ISO_NAME}
VOLID := Fedora_43_P_x86_64

# Project information
SRC_DIR := ./src
TMP_DIR := ./tmp

# Kickstart information
ROOT_PASSWD := $(shell grep ROOT_PASSWD ./.secrets | awk -F= '{print $2}')
USER_PASSWD := $(shell grep USER_PASSWD ./.secrets | awk -F= '{print $2}')

.PHONY: os_install destroy_vm clean build

${CUSTOM_ISO_PATH}: ${BASE_ISO_PATH} ${ISO_DIST_DIR} ${SRC_DIR}/grub.cfg ${SRC_DIR}/kickstart.cfg ${TMP_DIR}
	if [[ -f ${CUSTOM_ISO_PATH} ]]; then \
		rm ${CUSTOM_ISO_PATH}; \
	fi

	# Fill kickstart.cfg placeholders
	cp ${SRC_DIR}/kickstart.cfg ${TMP_DIR}/tmp_kickstart.cfg
	cat ${SRC_DIR}/packages.lst >> ${TMP_DIR}/tmp_kickstart.cfg
	echo '%end' >> ${TMP_DIR}/tmp_kickstart.cfg

	sed -i 's|@@@ROOT_PASSWD@@@|${ROOT_PASSWD}|' ${TMP_DIR}/tmp_kickstart.cfg
	sed -i 's|@@@USER_PASSWD@@@|${USER_PASSWD}|' ${TMP_DIR}/tmp_kickstart.cfg

	# Fill grub.cfg placeholders
	cp ${SRC_DIR}/grub.cfg ${TMP_DIR}/tmp_grub.cfg
	sed -i 's/@@@VOLID@@@/${VOLID}/g' ${TMP_DIR}/tmp_grub.cfg

	xorriso -indev ${BASE_ISO_PATH} \
		-outdev ${CUSTOM_ISO_PATH} \
		-volid ${VOLID} \
		-compliance no_emul_toc \
		-map ${TMP_DIR}/tmp_kickstart.cfg /kickstart.cfg \
		-map ${TMP_DIR}/tmp_grub.cfg /boot/grub2/grub.cfg \
		-map ${SRC_DIR}/bin /bin \
		-boot_image any replay

os_install: destroy_vm build
	virt-install \
		--name ${VM_NAME} \
		--memory 4096 \
		--vcpus 4 \
		--disk path=${ISO_DIST_DIR}/fedora.qcow2,size=40,format=qcow2 \
		--virt-type kvm \
		--cdrom ${CUSTOM_ISO_PATH} \
		--os-variant fedora-unknown

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



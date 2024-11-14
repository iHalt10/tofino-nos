#!/bin/sh
# NOTE: environments = ONIE_PLATFORM_PATH, WORK_DIR, ROOT_DIR, SDE, SDE_INSTALL, KERNEL_VERSION

set -e # Exit on error
set -x # Make command execution verbose

cp ${ONIE_PLATFORM_PATH}/overlay/etc/systemd/system/* ${ROOT_DIR}/etc/systemd/system/
cp ${ONIE_PLATFORM_PATH}/overlay/etc/systemd/network/* ${ROOT_DIR}/etc/systemd/network/

chroot ${ROOT_DIR} chmod 644 ${SDE_INSTALL}/lib/modules/bf_fpga.ko
chroot ${ROOT_DIR} chmod 644 ${SDE_INSTALL}/lib/modules/bf_kdrv.ko
chroot ${ROOT_DIR} chmod 644 ${SDE_INSTALL}/lib/modules/bf_knet.ko
chroot ${ROOT_DIR} mkdir -p /lib/modules/${KERNEL_VERSION}/extra/
chroot ${ROOT_DIR} ln -s ${SDE_INSTALL}/lib/modules/bf_fpga.ko /lib/modules/${KERNEL_VERSION}/extra/bf_fpga.ko
chroot ${ROOT_DIR} ln -s ${SDE_INSTALL}/lib/modules/bf_kdrv.ko /lib/modules/${KERNEL_VERSION}/extra/bf_kdrv.ko
chroot ${ROOT_DIR} ln -s ${SDE_INSTALL}/lib/modules/bf_knet.ko /lib/modules/${KERNEL_VERSION}/extra/bf_knet.ko
chroot ${ROOT_DIR} depmod -a ${KERNEL_VERSION}

chroot ${ROOT_DIR} systemctl enable bf_fpga_module.service
chroot ${ROOT_DIR} systemctl enable bf_kdrv_module.service
chroot ${ROOT_DIR} systemctl enable bf_knet_module.service

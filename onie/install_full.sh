#!/bin/sh
set -e # Exit on error

. /lib/onie/onie-blkdev-common

# NOTE: Default ONIE partition (must)
# 1 : LABEL="EFI System"
# 2 : LABEL="ONIE-BOOT"
# 3-?: (custom)
BASE_USER_PARTITION_NUMBER=3
BOOT_DISK="$(onie_get_boot_disk)"
UEFI_UUID="$(onie_get_uefi_uuid)"
ROOT_DIR="/mnt/root"
. /etc/machine.conf

echo
function log_info () {
    echo -e "\033[01;32m[INFO]\033[0m $@" >&1
}

function log_warn () {
    echo -e "\033[01;33m[WARN]\033[0m $@" >&2
}

function log_erro () {
    echo -e "\033[01;31m[ERRO]\033[0m $@" >&2
}

function get_disk_partition_number() {
    local disk="$1"
    if ! echo "${disk}" | grep -Eq "^${BOOT_DISK}[0-9]+$"; then
        log_warn "Invalid format. You must create a partition on the ONIE disk (format: ${BOOT_DISK}N)."
        return 1
    fi

    local num=$(echo "${disk}" | sed -E "s:^${BOOT_DISK}([0-9]+)$:\1:")

    if [ ${num} -lt ${BASE_USER_PARTITION_NUMBER} ]; then
        log_warn "Partition number ${num} is reserved (1:EFI System, 2:ONIE-BOOT)."
        return 1
    fi
    echo "${num}"
    return 0
}


function check_disk_space() {
    local num=$1
    local sector_size=$(sgdisk -p ${BOOT_DISK} | awk '/Logical sector size:/ { print $4 }')
    local part_size=$(($(sgdisk --pretend -N ${num} -i ${num} ${BOOT_DISK} | awk '/Partition size:/ { print $3}') * ${sector_size}))
    local estimated_size=$(echo "${REQUIRED_SIZE}" | awk '{print int($1 * 1.2)}')
    if [ ${estimated_size} -gt ${part_size} ]; then
        log_erro "${INSTALL_DISK} doesn't have enough space. [disk (${part_size} bytes) > estimated (${estimated_size} bytes)]"
        return 1
    fi
    return 0
}

[ -z "${INSTALL_DISK}" ] && log_erro "INSTALL_DISK environment variable is not set." && exit 1


CONSOLE_TTYS="$(cat /proc/cmdline | grep -Eo 'console=ttyS[0-9]+' | cut -d "=" -f2)"
if [ -z "${CONSOLE_TTYS}" ]; then
    log_erro "Failed to get device of 'ttyS{N}' from '/proc/cmdline'"
    exit 1
fi

CONSOLE_DEV=$(echo "${CONSOLE_TTYS}" | grep -o '[0-9]$')

CONSOLE_SPEED=$(cat /proc/cmdline | grep -Eo 'console=ttyS[0-9]+,[0-9]+' | cut -d "," -f2)
if [ -z "${CONSOLE_SPEED}" ]; then
    log_erro "Failed to get speed for 'ttyS{N}' from '/proc/cmdline'"
    exit 1
fi

DEFAULT_BOOT_ORDER="$(efibootmgr | grep "BootOrder:" | sed 's/BootOrder: //')"



WORK_DIR="$(realpath $0)"
WORK_DIR="$(dirname ${WORK_DIR})"
WORK_DIR="$(dirname ${WORK_DIR})"
cd ${WORK_DIR}
log_info "Working directory: ${WORK_DIR}"


log_info "Loading: ${WORK_DIR}/installer/nos-release"
. ${WORK_DIR}/installer/nos-release
NOS_NAME="${NAME}"


log_info "Loading: ${WORK_DIR}/installer/sde-release"
. ${WORK_DIR}/installer/sde-release


log_info "Loading: ${WORK_DIR}/installer/kernel-version"
KERNEL_VERSION="$(cat ${WORK_DIR}/installer/kernel-version)"


log_info "Loading: ${WORK_DIR}/installer/rootfs-size"
ROOT_FS_SIZE="$(cat ${WORK_DIR}/installer/rootfs-size)"

log_info "Loading: ${WORK_DIR}/installer/sde-size"
SDE_SIZE="$(cat ${WORK_DIR}/installer/sde-size)"

REQUIRED_SIZE="$(expr ${ROOT_FS_SIZE} + ${SDE_SIZE})"


partition_table="$(parted ${BOOT_DISK} print | grep -i "Partition Table" | awk '{print $3}')"
if [ "${partition_table}" != "gpt" ]; then
    log_erro "Partition Table is not GPT. Detected: ${partition_table}"
    exit 1
fi


install_disk_partition_number=$(get_disk_partition_number "${INSTALL_DISK}")
if [ $? -ne 0 ]; then
    log_erro "Invalid disk: ${INSTALL_DISK}"
    exit 1
fi

if [ -e "${INSTALL_DISK}" ]; then
    log_warn "${INSTALL_DISK} already exists. It will be deleted for re-creating partition."
    sgdisk -d ${install_disk_partition_number} ${BOOT_DISK}
    partprobe ${BOOT_DISK}
fi


log_info "Checking: ${INSTALL_DISK} disk space"
check_disk_space ${install_disk_partition_number} || exit 1


log_info "Creating ${INSTALL_DISK} partition"
sgdisk -N ${install_disk_partition_number} -c "${install_disk_partition_number}:${NOS_NAME}" ${BOOT_DISK}
partprobe ${BOOT_DISK}


log_info "Formatting ${INSTALL_DISK} with ext4."
mkfs.ext4 -F ${INSTALL_DISK}
ROOT_UUID="$(blkid ${INSTALL_DISK} | sed -n 's/.*UUID="\([^"]*\)".*/\1/p')"


log_info "Mounting ${INSTALL_DISK} to ${ROOT_DIR}"
mkdir -p ${ROOT_DIR}
mount ${INSTALL_DISK} ${ROOT_DIR}


log_info "Unpacking ${WORK_DIR}/rootfs.tar.xz"
tar -Jxf ${WORK_DIR}/rootfs.tar.xz -C ${ROOT_DIR}


log_info "Preparing mounts required for chroot environment setup"
mount -t sysfs -o nodev,noexec,nosuid none ${ROOT_DIR}/sys
mount -t proc -o nodev,noexec,nosuid none ${ROOT_DIR}/proc
mount -t devtmpfs devtmpfs ${ROOT_DIR}/dev
mount -t devpts devpts ${ROOT_DIR}/dev/pts
ln -s /proc/self/fd ${ROOT_DIR}/dev/fd


log_info "Installing p4studio (long time)"
mkdir -p "${ROOT_DIR}/${SDE_BASE}"
cp "${WORK_DIR}/installer/sde-release" "${ROOT_DIR}/${SDE_BASE}/"
tar -zxf "${WORK_DIR}/installer/${SDE_VERSION}.tar.gz" -C "${ROOT_DIR}/${SDE_BASE}" || true
chroot ${ROOT_DIR} find "${SDE_BASE}" -type d -exec chmod 777 {} \;
chroot ${ROOT_DIR} find "${SDE_BASE}" -type f -exec chmod a+rw,a-x {} \;
chroot ${ROOT_DIR} chmod -R 777 "${SDE_INSTALL}/bin"
chroot ${ROOT_DIR} chmod 777 "${SDE}/extract_all.sh"
chroot ${ROOT_DIR} chmod 777 "${SDE}/install.sh"
chroot ${ROOT_DIR} chmod 777 "${SDE}/p4runtime_update_config.py"
chroot ${ROOT_DIR} chmod 777 "${SDE}/run_bfshell.sh"
chroot ${ROOT_DIR} chmod 777 "${SDE}/run_p4_tests.sh"
chroot ${ROOT_DIR} chmod 777 "${SDE}/run_switchd.sh"
chroot ${ROOT_DIR} chmod 777 "${SDE}/run_tofino_model.sh"


ONIE_PLATFORM_PATH="${WORK_DIR}/installer/platforms/${onie_platform}"
if [ -d "${ONIE_PLATFORM_PATH}" ]; then
    log_info "Running the install.sh for ${onie_platform}"
    ONIE_PLATFORM_PATH="${ONIE_PLATFORM_PATH}" WORK_DIR="${WORK_DIR}" ROOT_DIR="${ROOT_DIR}" SDE="${SDE}" SDE_INSTALL="${SDE_INSTALL}" KERNEL_VERSION="${KERNEL_VERSION}" \
        /bin/sh "${ONIE_PLATFORM_PATH}/install.sh"
else
    log_info "Skipping the install.sh for ${onie_platform}"
fi


log_info "Copying /etc/machine.conf to ${ROOT_DIR}/etc/machine.conf"
cp /etc/machine.conf ${ROOT_DIR}/etc/machine.conf


log_info "Updating ${ROOT_DIR}/etc/fstab with root filesystem"
echo "UUID=${ROOT_UUID} / ext4 errors=remount-ro 0 1" >> ${ROOT_DIR}/etc/fstab
log_info "Updating ${ROOT_DIR}/etc/fstab with EFI partition"
echo "UUID=${UEFI_UUID} /boot/efi vfat umask=0077 0 1" >> ${ROOT_DIR}/etc/fstab


log_info "Creating EFI mount directory at ${ROOT_DIR}/boot/efi"
mkdir -p ${ROOT_DIR}/boot/efi


log_info "Mounting the EFI partition in the chroot environment"
chroot ${ROOT_DIR} mount /boot/efi


log_info "Creating GRUB configuration file for ${NOS_NAME} at ${ROOT_DIR}/etc/default/grub"
cat <<EOF > ${ROOT_DIR}/etc/default/grub
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_TERMINAL="console serial"
GRUB_SERIAL_COMMAND="serial --unit=${CONSOLE_DEV} --speed=${CONSOLE_SPEED} --parity=no --word=8 --stop=1"
GRUB_CMDLINE_LINUX_DEFAULT=""
GRUB_CMDLINE_LINUX="console=tty0 console=${CONSOLE_TTYS},${CONSOLE_SPEED},n,8,1 intel_idle.max_cstate=0 net.ifnames=0 biosdevname=0"
GRUB_DISTRIBUTOR="${NOS_NAME}"
EOF


log_info "Creating GRUB configuration file for ONIE at ${ROOT_DIR}/etc/grub.d/42_ONIE_BOOT"
cat <<EOF2 > ${ROOT_DIR}/etc/grub.d/42_ONIE_BOOT
#!/bin/sh
set -e

echo "Adding Menu entry to chainload ONIE"
cat <<EOF
menuentry ONIE {
  search --no-floppy --fs-uuid --set=root "${UEFI_UUID}"
  echo 'Loading ONIE ...'
  chainloader /EFI/onie/grubx64.efi
}
EOF
EOF2
chroot ${ROOT_DIR} chmod 755 /etc/grub.d/42_ONIE_BOOT


log_info "Linking device to UUID for GRUB"
mkdir -p ${ROOT_DIR}/dev/disk/by-uuid
ln -s ../../..${INSTALL_DISK} ${ROOT_DIR}/dev/disk/by-uuid/${ROOT_UUID}
log_info "Linked ${INSTALL_DISK} to ${ROOT_DIR}/dev/disk/by-uuid/${ROOT_UUID}"


log_info "Installing GRUB bootloader to ${BOOT_DISK} with bootloader ID 'grub'"
chroot ${ROOT_DIR} grub-install --bootloader-id=tofino ${BOOT_DISK}


log_info "Updating GRUB configuration in the chroot environment"
chroot ${ROOT_DIR} update-grub


log_info "Creating efiboot for ${NOS_NAME} (efibootmgr)"
efibootmgr --quiet --create-only --disk ${BOOT_DISK} --part 1 --label "${NOS_NAME}" --loader "/EFI/tofino/grubx64.efi"
new_boot="$(efibootmgr | grep "${NOS_NAME}" | sed -n 's/^Boot\([0-9A-F]*\)\*.*/\1/p')"
efibootmgr --quiet --bootorder "${new_boot},${DEFAULT_BOOT_ORDER}"


log_info "Show EFI boot entries"
efibootmgr


log_info "Installed ${NOS_NAME}"

sync
reboot
exit 0

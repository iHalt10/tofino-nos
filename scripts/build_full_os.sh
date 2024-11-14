#!/bin/bash
set -e # Exit on error

OUTPUT="$1"
KERNEL_VERSION="$2"
ASSETS_DIR="/vagrant"
ASSETS_DEBOS_RECIPE="${ASSETS_DIR}/debos/full.yaml"
ASSETS_ONIE_INSTALL_SCRIPT="${ASSETS_DIR}/onie/install_full.sh"
ASSETS_ONIE_BASE_INSTALLER_BIN="${ASSETS_DIR}/onie/sharch_body.sh"
ASSETS_PLATFORMS_DIR="${ASSETS_DIR}/platforms"
. ${ASSETS_DIR}/p4studio/sde-release

NOS_NAME="Tofino-NOS"
NOS_VERSION="$(date +"%Y.%m.%d")"
NOS_PRETTY_NAME="${NOS_NAME}:${NOS_VERSION}"

WORK_DIR="$(mktemp -d)"
CURRENT_DIR="${PWD}"


function log_info () {
    echo -e "\033[01;32m[INFO]\033[0m $@"
}

log_info "Working directory: ${WORK_DIR}"
cd ${WORK_DIR}


export GOPATH="/opt/go"
export PATH="${GOPATH}/bin:${PATH}"

if [ ! -d ${GOPATH} ]; then
    log_info "Installing golang (${GOPATH})"
    apt-get install -y libglib2.0-dev libostree-dev # for golang
    wget https://go.dev/dl/go1.23.2.linux-amd64.tar.gz
    tar -xzf go1.23.2.linux-amd64.tar.gz -C $(dirname ${GOPATH})
    rm go1.23.2.linux-amd64.tar.gz
fi

if ! command -v debos 1>/dev/null 2>&1; then
    log_info "Installing debos"
    apt-get install -y qemu-system-x86 qemu-user-static debootstrap systemd-container # for debos
    go install github.com/go-debos/debos/cmd/debos@latest
fi


log_info "Creating ${WORK_DIR}/installer directory"
mkdir installer


log_info "Creating ${WORK_DIR}/installer/nos-release"
cat <<EOF > installer/nos-release
PRETTY_NAME="${NOS_PRETTY_NAME}"
NAME="${NOS_NAME}"
VERSION_ID="${NOS_VERSION}"
EOF


log_info "Copying ${WORK_DIR}/installer/sde-release"
cp ${ASSETS_DIR}/p4studio/sde-release installer/


log_info "Creating ${WORK_DIR}/installer/sde-size"
du -s -B 1 ${SDE_BASE}/${SDE_VERSION} | awk '{print $1}' > installer/sde-size


log_info "Creating ${WORK_DIR}/installer/kernel-version"
echo "${KERNEL_VERSION}" > installer/kernel-version


log_info "Compressing ${SDE_BASE}/${SDE_VERSION} to ${WORK_DIR}/installer/${SDE_VERSION}.tar.gz"
cd ${SDE_BASE}
tar -zcf ${WORK_DIR}/installer/${SDE_VERSION}.tar.gz ${SDE_VERSION}
cd ${WORK_DIR}


log_info "Creating ${WORK_DIR}/rootfs.tar.xz by debos (debootstrap) tool"
debos -b qemu --scratchsize=10G --cpus=$(nproc) -t "work_dir:${WORK_DIR}" -t "kernel_version:${KERNEL_VERSION}" "${ASSETS_DEBOS_RECIPE}"


log_info "Copying ${ASSETS_PLATFORMS_DIR}/ to ${WORK_DIR}/installer/platforms"
cp -r ${ASSETS_PLATFORMS_DIR} installer/


log_info "Copying ${ASSETS_ONIE_INSTALL_SCRIPT} to ${WORK_DIR}/installer/install.sh"
cp ${ASSETS_ONIE_INSTALL_SCRIPT} installer/install.sh
chmod a+wx installer/install.sh


log_info "Creating base ${WORK_DIR}/onie-installer.bin"
cat "${ASSETS_ONIE_BASE_INSTALLER_BIN}" > onie-installer.bin
chmod a+wx onie-installer.bin


log_info "Creating ${WORK_DIR}/payload.tar archive including '${WORK_DIR}/{ installer/, rootfs.tar.xz }'"
tar cf payload.tar installer rootfs.tar.xz


log_info "Deleting '${WORK_DIR}/{ installer/, rootfs.tar.xz }'"
rm rootfs.tar.xz
rm -rf installer


log_info "Writing ${WORK_DIR}/payload.tar checksum to ${WORK_DIR}/onie-installer.bin"
checksum="$(sha1sum payload.tar | awk '{print $1}')"
sed -i -e "s/%%IMAGE_SHA1%%/${checksum}/" onie-installer.bin


log_info "Writing ${WORK_DIR}/payload.tar to ${WORK_DIR}/onie-installer.bin"
cat payload.tar >> onie-installer.bin


mv onie-installer.bin "${OUTPUT}"
log_info "Successfully completed, ${CURRENT_DIR}/onie-installer.bin"


log_info "Cleanup ${WORK_DIR}"
cd "${CURRENT_DIR}"
rm -rf "${WORK_DIR}"

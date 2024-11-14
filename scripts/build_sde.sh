#!/bin/bash
set -e # Exit on error.

ASSETS_DIR="/vagrant"
. ${ASSETS_DIR}/p4studio/sde-release

P4RUNTIME_VERSION="1.4.1"

PYTHON_INSTALL_DIR="/opt/python"
PYTHON_VERSION="3.10.9"

function log_erro () {
    echo -e "\033[01;31m[ERRO]\033[0m $@" >&2
}

[ -z "${SDE_ARCHIVE}" ] && log_erro "SDE_ARCHIVE environment variable is not set." && exit 1
[ -z "${BSP_ARCHIVE}" ] && log_erro "BSP_ARCHIVE environment variable is not set." && exit 1
[ -z "${SDE_PROFILE}" ] && log_erro "SDE_PROFILE environment variable is not set." && exit 1
[ ! "$(basename "${SDE_ARCHIVE}")" = "${SDE_VERSION}.tgz" ] && log_erro "Msut SDE version ${SDE_VERSION}." && exit 1

set -x # Make command execution verbose

###################################################
################### Install linux header
###################################################
apt-get install -y "linux-headers-$(uname -r)"


###################################################
################### Install Python3
###################################################
if [ ! -d "${PYTHON_INSTALL_DIR}" ]; then
    apt-get install -y libssl-dev libreadline-dev libncurses5-dev libncursesw5-dev zlib1g-dev libbz2-dev libffi-dev tk-dev libdb-dev libgdbm-dev libsqlite3-dev xz-utils liblzma-dev
    mkdir -p "${PYTHON_INSTALL_DIR}/src"
    cd "${PYTHON_INSTALL_DIR}/src"
    wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz
    tar xf Python-${PYTHON_VERSION}.tar.xz
    cd Python-${PYTHON_VERSION}
    ./configure --prefix="${PYTHON_INSTALL_DIR}" --with-openssl-rpath=auto --with-ensurepip=install --enable-optimizations
    make -j$(nproc)
    make install

    echo "/usr/lib/python3/dist-packages" > "${PYTHON_INSTALL_DIR}/lib/python3.10/site-packages/host.pth"
    ln -s /usr/lib/python3/dist-packages/apt_pkg.cpython-39-x86_64-linux-gnu.so "${PYTHON_INSTALL_DIR}/lib/python3.10/site-packages/apt_pkg.so"

    apt-get install -y python3-pip # NOTE: 20.3.4
    new_pip_version="$(pip3 -V | awk '{print $2}')"
    ${PYTHON_INSTALL_DIR}/bin/pip3 install pip==${new_pip_version} # NOTE: 22.3.1 -> 20.3.4
    update-alternatives --install /usr/bin/python3 python3 ${PYTHON_INSTALL_DIR}/bin/python3.10 1
    hash -r
fi


###################################################
################### Build P4 studio
###################################################
mkdir -p "${SDE_BASE}"
tar -zxf "${SDE_ARCHIVE}" -C "${SDE_BASE}"

cd "${SDE}/p4studio"
./p4studio profile apply --jobs $(nproc) --verbosity DEBUG --bsp-path "${BSP_ARCHIVE}" "${SDE_PROFILE}"


###################################################
################### Adjustment p4 studio files
###################################################
find "${SDE_BASE}" -type d -exec chmod 777 {} \;
find "${SDE_BASE}" -type f -exec chmod a+rw,a-x {} \;
chmod -R 777 "${SDE_INSTALL}/bin"

cd "${SDE_INSTALL}/bin"
ln -s python3.10 python3
cd "${SDE}/p4studio"

######## Build P4 studio
TMP_DIR="$(mktemp -d)"
# echo "../../../local/lib/python3.10/dist-packages" > "${SDE_INSTALL}/lib/python3.10/site-packages/local.pth"

######## Upgrade P4 runtime (old: v1.0.0-rc3)
wget -P "${TMP_DIR}" https://github.com/p4lang/p4runtime/archive/refs/tags/v${P4RUNTIME_VERSION}.tar.gz
tar -zxf "${TMP_DIR}/v${P4RUNTIME_VERSION}.tar.gz" -C "${TMP_DIR}"
rm -r "${SDE_INSTALL}/lib/python3.10/site-packages/p4"
cp -r "${TMP_DIR}/p4runtime-${P4RUNTIME_VERSION}/py/p4" "${SDE_INSTALL}/lib/python3.10/site-packages/p4"


######## Install p4runtime-shell with tofino.py (latest)
mkdir -p "${TMP_DIR}/p4runtime-shell"
git clone https://github.com/p4lang/p4runtime-shell.git "${TMP_DIR}/p4runtime-shell"
cp -r "${TMP_DIR}/p4runtime-shell/p4runtime_sh" "${SDE_INSTALL}/lib/python3.10/site-packages"
cp "${TMP_DIR}/p4runtime-shell/config_builders/tofino.py" "${SDE_INSTALL}/bin"
chmod 755 "${SDE_INSTALL}/bin/tofino.py"

rm -r "${TMP_DIR}"

######## Bind to a specific python3.10
files=(
    bf-p4c
    bfrt_schema.py
    gencli
    generate_tofino_pd
    p4c-gen-bfrt-conf
    p4c-gen-conf
    ptf
    split_pd_thrift.py
    tofino.py
)

for file in "${files[@]}"; do
    sed -i "1c#\!${SDE_INSTALL}/bin/python3.10" "${SDE_INSTALL}/bin/${file}"
done

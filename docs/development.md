# Developing Tofino NOS

## Testing onie-installer.bin
The ONIE repository contains a tool that uses qemu-kvm to emulate the ONIE system.

## Preparing the ONEI System with qemu
- [opencomputeproject/onie:2024.08 (Github) - machine/kvm_x86_64/INSTALL](https://github.com/opencomputeproject/onie/blob/5636a1eb22a4a6f0d27fa650a88a4ba74a00f148/machine/kvm_x86_64/INSTALL)

```shell
$ apt-get install -y git qemu ovmf

$ git config --global user.email "${USER}@example.com"
$ git config --global user.name "${USER}"

$ git clone https://github.com/opencomputeproject/onie.git
$ cd onie
$ git checkout tags/2024.08
$ git config --global --add safe.directory "${PWD}/build/crosstool-ng/crosstool-ng-1.24.0"

$ # NOTE: https://github.com/opencomputeproject/onie/issues/992#issuecomment-1074571562
$ cp ./machine/kvm_x86_64/kernel/config-insecure ./machine/kvm_x86_64/kernel/config
$ sed -i 's/^SECURE_BOOT_ENABLE = .*/SECURE_BOOT_ENABLE = no/' ./machine/kvm_x86_64/machine.make
$ sed -i 's/^SECURE_BOOT_EXT = .*/SECURE_BOOT_EXT = no/' ./machine/kvm_x86_64/machine.make
$ sed -i 's/^SECURE_GRUB = .*/SECURE_GRUB = no/' ./machine/kvm_x86_64/machine.make
$ sed -i '/^MACHINE_SECURITY_MAKEFILE/d' ./machine/kvm_x86_64/machine.make
$ sed -i 's/python-sphinx/sphinx-doc sphinx-common/g' ./build-config/Makefile

$ cd build-config/
$ # NOTE: https://stackoverflow.com/questions/17466017/how-to-solve-you-must-not-be-root-to-run-crosstool-ng-when-using-ct-ng
$ export CT_EXPERIMENTAL=y # root user
$ export CT_ALLOW_BUILD_AS_ROOT=y # root user
$ export CT_ALLOW_BUILD_AS_ROOT_SURE=y # root user
$ make debian-prepare-build-host
$ make MACHINE=kvm_x86_64 all recovery-iso
```

Building the above recipe currently fails.
Therefore, we are backing up the image from when the build was successful.

- [iHalt10/onie-recovery-x86_64-kvm-backup (Github)](https://github.com/iHalt10/onie-recovery-x86_64-kvm-backup)
- [ihalt10/onie:2024.08 (Dockerhub)](https://hub.docker.com/repository/docker/ihalt10/onie/general)

### with docker

```
tofino-nos $ docker run --rm -it -v ${PWD}/build:/var/www/html ihalt10/onie:2024.08 bash

root@c790706f3460:/# apachectl start
AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 172.17.0.2. Set the 'ServerName' directive globally to suppress this message
root@c790706f3460:/# mk-vm.sh

... select: ONIE: Embed ONIE ...
... reboo ...
... select: ONIE: Rescue ...

ONIE:/ # export INSTALL_DISK=/dev/vda3
ONIE:/ # onie-nos-install http://172.17.0.2/onie-installer.bin

```

## Quickly generate onie-installer.bin without debos
First, run the following:
```shell
$ cd /vagrant/build
$ archive_path=onie-installer.bin
$ sed -e '1,/^exit_marker$/d' $archive_path | tar xf -
$ rm onie-installer.bin
```

Edit `./scripts/build_full_os.sh` as follows.
```shell
... omitted ...
# log_info "Compressing ${SDE_BASE}/${SDE_VERSION} to ${WORK_DIR}/installer/${SDE_VERSION}.tar.gz"
# cd ${SDE_BASE}
# tar -zcf ${WORK_DIR}/installer/${SDE_VERSION}.tar.gz ${SDE_VERSION}
# cd ${WORK_DIR}


# log_info "Creating ${WORK_DIR}/rootfs.tar.xz by debos (debootstrap) tool"
# debos -b qemu --scratchsize=10G --cpus=$(nproc) -t "work_dir:${WORK_DIR}" -t "kernel_version:${KERNEL_VERSION}" "${ASSETS_DEBOS_RECIPE}"

cp ${ASSETS_DIR}/build/installer/rootfs-size ${WORK_DIR}/installer/
cp ${ASSETS_DIR}/build/installer/bf-sde-9.11.2.tar.gz ${WORK_DIR}/installer/
cp ${ASSETS_DIR}/build/rootfs.tar.xz ${WORK_DIR}/
... omitted ...
```

# Tofino NOS

## Requirements
- Building
  - tool: vagrant 
  - disk: 8G or more
- ONEI System
  - memory: 8G or more
  - disk: 8G or more

## Building
Please prepare the following files:
- ./p4studio/bf-sde-9.11.2.tgz
- ./p4studio/bf-reference-bsp-9.11.2.tgz
- ./p4studio/profile.yaml

Below is a sample profile.yaml.
```yaml
---
# Note: About all fields in 'profile.yaml' (bf-sde-9.11.2/p4studio/profiles/README.md)
global-options:
  asic: true
features:
  bf-diags:
    thrift-diags: false
  bf-platforms:
    newport: true
    newport-diags: true
  drivers:
    bfrt: true
    bfrt-generic-flags: true
    grpc: true
    p4rt: true
    thrift-driver: false
  switch:
    profile: y1_tofino2
    thrift-switch: false
architectures:
  - tofino2
```

Build it with the following command.
```shell
$ vagrant up
    ... omitted ...
    default: Provisioned ! So, shutdown.
    default: Do 'vagrant up' again.
$ vagrant up
$ vagrant ssh
vagrant@node:~$ sudo su -
root@node:~# cd /vagrant/
root@node:/vagrant# export SDE_ARCHIVE="${PWD}/p4studio/bf-sde-9.11.2.tgz"
root@node:/vagrant# export BSP_ARCHIVE="${PWD}/p4studio/bf-reference-bsp-9.11.2.tgz"
root@node:/vagrant# export SDE_PROFILE="${PWD}/p4studio/profile.yaml"
root@node:/vagrant# make # full mode or
root@node:/vagrant# make full # full mode or
root@node:/vagrant# make mini # mini mode (todo)
```

Output to "./build/onie-installer.bin".

## Installing on ONEI System
Launch ONIE Rescue Mode.
```
ONIE:/ # export INSTALL_DISK=/dev/sda3 # Please adapt to your environment
ONIE:/ # onie-nos-install http://x.x.x.x/onie-installer.bin # or
ONIE:/ # onie-nos-install file://mnt/usb/onie-installer.bin
```

- Default User
  - name: admin
  - pass: passward

## Troubleshooting

### make

```shell
$ make
make: Warning: File 'Makefile' has modification time 0.15 s in the future
make: warning:  Clock skew detected.  Your build may be incomplete.
$ ntpdate ntp.nict.jp
```

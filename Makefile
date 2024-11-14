.PHONY: all full mini clean

KERNEL_VERSION := 5.10.0-32-amd64
RUNNING_KERNEL_VERSION := $(shell uname -r)
OUTPUT := $(PWD)/build/onie-installer.bin
GOAL := $(or $(word 1,$(MAKECMDGOALS)),full)
include p4studio/sde-release

define ERROR_MESSAGE_FOR_KERNEL_VERSION
Kernel version mismatch!
Required version: $(KERNEL_VERSION)
Current version: $(RUNNING_KERNEL_VERSION)
Please install the correct kernel:
    apt-get install linux-image-$(KERNEL_VERSION)
    apt remove -y linux-image-$(RUNNING_KERNEL_VERSION) # case of downgrade
    update-grub
    shutdown -h now
    > Then run "vagrant up".
endef

ifneq ($(USER), root)
	$(error This Makefile must be run as root!)
endif

ifneq ($(KERNEL_VERSION), $(RUNNING_KERNEL_VERSION))
	$(error $(ERROR_MESSAGE_FOR_KERNEL_VERSION))
endif

define check_env_vars
	@ if [ -z "$$SDE_ARCHIVE" ] || [ -z "$$BSP_ARCHIVE" ] || [ -z "$$SDE_PROFILE" ]; then \
		echo "Error: Required environment variables are not set."; \
		echo "Please set SDE_ARCHIVE, BSP_ARCHIVE, and SDE_PROFILE."; \
		exit 1; \
	fi
	@ [ -f "$$SDE_ARCHIVE" ] || (echo "Error: No such $$SDE_ARCHIVE file." && exit 1)
	@ [ -f "$$BSP_ARCHIVE" ] || (echo "Error: No such $$BSP_ARCHIVE file." && exit 1)
	@ [ -f "$$SDE_PROFILE" ] || (echo "Error: No such $$SDE_PROFILE file." && exit 1)
endef

define check_kernel_version
	@ if [ -z "$$SDE_PROFILE" ]; then \
		echo "Error: Required environment variables are not set."; \
		echo "Please set SDE_ARCHIVE, BSP_ARCHIVE, and SDE_PROFILE."; \
		exit 1; \
	fi
endef

all: full

full: $(OUTPUT)

mini: $(OUTPUT)

$(OUTPUT): $(SDE_INSTALL)
	@echo "Generating $(OUTPUT) from $(GOAL) ..."
	mkdir -p build
	@if [ "$(GOAL)" = "full" ]; then \
		bash scripts/build_full_os.sh $(OUTPUT) $(KERNEL_VERSION); \
	elif [ "$(GOAL)" = "mini" ]; then \
		echo "Mini ONIE installer content" > $(OUTPUT); \
	fi

$(SDE_INSTALL):
	$(check_env_vars)
	@echo "Building p4studio ..."
	bash scripts/build_sde.sh

clean:
	@echo "Cleaning up..."
	rm -rf build
	rm -rf $(SDE_BASE)

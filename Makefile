include ../common/format.mk
include ../common/dokcer.mk

BSP ?= rpi3


QEMU_MISSING_STRING = "This board is not yet supported for QEMU"

ifeq($(BSP),rpi3)
	TARGET = aarch64-uknown-none-softfloat
	KERNEL_BIN = kernel8.img
	QEMU_BINARY = qemu-system-aarch64
	QEMU_MACHINE_TYPE = raspi3
	QEMU_RELEASE_ARGS = -d in_asm -display none
	OBJDUMP_BINARY = aarch64-none-elf-objdump
	NM_BINARY = aarch64-none-elf-nm
	READELF_BINARY = aarch64-none-elf-readelf
	LD_SCRIPT_PATH = $(shell pwd)/src/bsp/raspberrypi
	RUSTC_MISC_ARGS = -C target-cpu=cortex-a53
else ifeq($(BSP), rpi4)
	TARGET = aarch64-uknown-none-softfloat
	KERNEL_BIN = kernel8.img
	QEMU_BINARY = qemu-system-aarch64
	QEMU_MACHINE_TYPE = rpi4
	QEMU_RELEASE_ARGS = -d in_asm -display none
	OBJDUMP_BINARY = aarch64-none-elf-objdump
	NM_BINARY = aarch64-none-elf-nm
	READELF_BINARY = aarch64-none-elf-readelf
	LD_SCRIPT_PATH = $(shell pwd)/src/bsp/raspberrypi
	RUSTC_MISC_ARGS = -C target-cpu=cortex-a72
endif

export LD_SCRIPT_PATH

KERNEL_MANIFEST = Cargo.toml
KERNEL_LINKER_SCRIPT = kernel.id
LAST_BUILD_CONFIG = target/$(BSP).build_config

KERNEL_ELF = target/$(TARGET)/release/kernel
include ./common/format.mk
include ./common/docker.mk
include ./common/operating_system.mk

BSP ?= rpi3

QEMU_MISSING_STRING = "This board is not yet supported for QEMU"

ifeq	($(BSP),rpi3)
	TARGET 				= aarch64-unknown-none-softfloat
	KERNEL_BIN 			= kernel8.img
	QEMU_BINARY 		= qemu-system-aarch64
	QEMU_MACHINE_TYPE 	= raspi3
	QEMU_RELEASE_ARGS 	= -d in_asm -display none
	OBJDUMP_BINARY 		= aarch64-none-elf-objdump
	NM_BINARY 			= aarch64-none-elf-nm
	READELF_BINARY 		= aarch64-none-elf-readelf
	LD_SCRIPT_PATH 		= $(shell pwd)/src/bsp/raspberrypi
	RUSTC_MISC_ARGS 	= -C target-cpu=cortex-a53
else ifeq	($(BSP), rpi4)
	TARGET 				= aarch64-unknown-none-softfloat
	KERNEL_BIN 			= kernel8.img
	QEMU_BINARY 		= qemu-system-aarch64
	QEMU_MACHINE_TYPE 	=
	QEMU_RELEASE_ARGS 	= -d in_asm -display none
	OBJDUMP_BINARY 		= aarch64-none-elf-objdump
	NM_BINARY 			= aarch64-none-elf-nm
	READELF_BINARY 		= aarch64-none-elf-readelf
	LD_SCRIPT_PATH 		= $(shell pwd)/src/bsp/raspberrypi
	RUSTC_MISC_ARGS 	= -C target-cpu=cortex-a72
endif

export LD_SCRIPT_PATH

KERNEL_MANIFEST = Cargo.toml
KERNEL_LINKER_SCRIPT = kernel.ld
LAST_BUILD_CONFIG = target/$(BSP).build_config

KERNEL_ELF = target/$(TARGET)/release/kernel

KERNEL_ELF_DEPS = $(filter-out %: ,$(file < $(KERNEL_ELF).d)) $(KERNEL_MANIFEST) $(LAST_BUILD_CONFIG)

RUSTFLAGS = $(RUSTC_MISC_ARGS)	\
	-C link-arg=--library-path=$(LD_SCRIPT_PATH) \
	-C link-arg=--script=$(KERNEL_LINKER_SCRIPT)

RUSTFLAGS_PEDANTIC = $(RUSTFLAGS) 	\
	-D warnings	\
	-D missing_docs

FEATURES = --features bsp_$(BSP)
COMPILER_ARGS = --target=$(TARGET) \
	$(FEATURES)						\
	--release

RUSTC_CMD = cargo rustc $(COMPILER_ARGS)
DOC_CMD = cargo doc $(COMPILER_ARGS)
CLIPPY_CMD = cargo clipply $(COMPILER_ARGS)
OBJCOPY_CMD = rust-objcopy \
	--strip-all				\
	-O binary

EXEC_QEMU = $(QEMU_BINARY) -M $(QEMU_MACHINE_TYPE)

DOCKER_CMD = docker run -t --rm -v $(shell pwd):/work/tutorial -w /work/tutorial
DOCKER_CMD_INTERACT = $(DOCKER_CMD) -i

DOCKER_QEMU = $(DOCKER_CMD_INTERACT) $(DOCKER_IMAGE)
DOCKER_TOOLS = $(DOCKER_CMD) $(DOCKER_IMAGE)


.PHONY: all doc qemu clippy readelf objdump nm check

all: $(KERNEL_BIN)

##------------------------------------------------------------------------------
## Save the configuration as a file, so make understands if it changed.
##------------------------------------------------------------------------------
$(LAST_BUILD_CONFIG):
	@rm -f target/*.build_config
	@mkdir -p target
	@touch $(LAST_BUILD_CONFIG)

##------------------------------------------------------------------------------
## Compile the kernel ELF
##------------------------------------------------------------------------------
$(KERNEL_ELF): $(KERNEL_ELF_DEPS)
	$(call color_header, "Compiling kernel ELF - $(BSP)")
	@RUSTFLAGS="$(RUSTFLAGS_PEDANTIC)" $(RUSTC_CMD)

##------------------------------------------------------------------------------
## Generate the stripped kernel binary
##------------------------------------------------------------------------------
$(KERNEL_BIN): $(KERNEL_ELF)
	$(call color_header, "Generating stripped binary")
	@$(OBJCOPY_CMD) $(KERNEL_ELF) $(KERNEL_BIN)
	$(call color_progress_prefix, "Name")
	@echo $(KERNEL_BIN)
	$(call color_progress_prefix, "Size")
	@printf '%s KiB\n' `du -k $(KERNEL_BIN) | cut -f1`

##------------------------------------------------------------------------------
## Generate the documentation
##------------------------------------------------------------------------------
doc:
	$(call color_header, "Generating docs")
	@$(DOC_CMD) --document-private-items --open

##------------------------------------------------------------------------------
## Run the kernel in QEMU
##------------------------------------------------------------------------------
ifeq ($(QEMU_MACHINE_TYPE),) # QEMU is not supported for the board.

qemu:
	$(call color_header, "$(QEMU_MISSING_STRING)")

else # QEMU is supported.

qemu: $(KERNEL_BIN)
		$(call color_header, "Launching QEMU")
		@$(DOCKER_QEMU) $(EXEC_QEMU) $(QEMU_RELEASE_ARGS) -kernel $(KERNEL_BIN)
endif

##------------------------------------------------------------------------------
## Run clippy
##------------------------------------------------------------------------------
clippy:
	@RUSTFLAGS="$(RUSTFLAGS_PEDANTIC)" $(CLIPPY_CMD)

##------------------------------------------------------------------------------
## Clean
##------------------------------------------------------------------------------
clean:
	rm -rf target $(KERNEL_BIN)

##------------------------------------------------------------------------------
## Run readelf
##------------------------------------------------------------------------------
readelf: $(KERNEL_ELF)
	$(call color_header, "Launching readelf")
	@$(DOCKER_TOOLS) $(READELF_BINARY) --headers $(KERNEL_ELF)

##------------------------------------------------------------------------------
## Run objdump
##------------------------------------------------------------------------------
objdump: $(KERNEL_ELF)
	$(call color_header, "Launching objdump")
	@$(DOCKER_TOOLS) $(OBJDUMP_BINARY) --disassemble --demangle \
                --section .text   \
                $(KERNEL_ELF) | rustfilt

##------------------------------------------------------------------------------
## Run nm
##------------------------------------------------------------------------------
nm: $(KERNEL_ELF)
	$(call color_header, "Launching nm")
	@$(DOCKER_TOOLS) $(NM_BINARY) --demangle --print-size $(KERNEL_ELF) | sort | rustfilt

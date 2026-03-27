# Makefile — PicoRV32 FreeRTOS build
#
# Outputs: freertos.elf  freertos.hex  freertos.dis

CROSS   := /home/test/xpack-riscv-none-elf-gcc-14.2.0-3/bin/riscv-none-elf-
CC      := $(CROSS)gcc
AS      := $(CROSS)gcc   # use GCC as assembler (handles .S preprocessing)
LD      := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump

FREERTOS_DIR := ../../FreeRTOS-Kernel-11.1.0

ARCH_FLAGS  := -march=rv32im -mabi=ilp32
OPT_FLAGS   := -Os -ffunction-sections -fdata-sections
WARN_FLAGS  := -Wall -Wno-unused-function
CFLAGS      := $(ARCH_FLAGS) $(OPT_FLAGS) $(WARN_FLAGS) \
               -nostdlib -ffreestanding \
               -I. \
               -I$(FREERTOS_DIR)/include \
               -I$(FREERTOS_DIR)/portable/GCC/RISC-V

LDFLAGS     := $(ARCH_FLAGS) -nostdlib -nostartfiles \
               -T freertos.ld \
               -Wl,--no-relax \
               -Wl,--gc-sections \
               -Wl,-Map=freertos.map

SRCS_C := \
    port.c \
    main_freertos.c \
    syscalls.c \
    $(FREERTOS_DIR)/tasks.c \
    $(FREERTOS_DIR)/list.c \
    $(FREERTOS_DIR)/queue.c \
    $(FREERTOS_DIR)/portable/MemMang/heap_1.c

SRCS_S := \
    start_freertos.S \
    portASM.S

OBJS := $(SRCS_C:.c=.o) $(SRCS_S:.S=.o)

.PHONY: all clean hex prog

all: freertos.hex freertos.dis

freertos.elf: $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $^
	@echo "=== Size ==="
	$(CROSS)size $@

freertos.bin: freertos.elf
	$(OBJCOPY) -O binary $< $@

freertos.hex: freertos.bin
	python3 ../bin2hex.py freertos.bin freertos.hex
	@echo "ROM usage: $$(wc -w < freertos.hex) words"

freertos.dis: freertos.elf
	$(OBJDUMP) -d -S $< > $@

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.S
	$(AS) $(CFLAGS) -c -o $@ $<

# Update soc_top.v to point at freertos.hex and expand ROM to 16K,
# then trigger Quartus compile from parent directory
prog: freertos.hex
	@echo "Copy firmware.hex to parent for Quartus"
	cp freertos.hex ../../firmware.hex || cp freertos.hex ../../../firmware.hex
	@echo "Now re-synthesize with Quartus and program the FPGA"

clean:
	rm -f $(OBJS) freertos.elf freertos.bin freertos.hex freertos.dis freertos.map

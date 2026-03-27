TOOLCHAIN_PREFIX = /home/test/xpack-riscv-none-elf-gcc-14.2.0-3/bin/riscv-none-elf-
CC      = $(TOOLCHAIN_PREFIX)gcc
OBJCOPY = $(TOOLCHAIN_PREFIX)objcopy
OBJDUMP = $(TOOLCHAIN_PREFIX)objdump
SIZE    = $(TOOLCHAIN_PREFIX)size

CFLAGS  = -march=rv32im -mabi=ilp32 -Os -Wall -nostdlib -ffreestanding
LDFLAGS = -T firmware.ld -nostdlib -Wl,--no-relax

TARGET = firmware

.PHONY: all clean

all: $(TARGET).hex $(TARGET).dis

$(TARGET).elf: start.S main.c firmware.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ start.S main.c
	$(SIZE) $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).dis: $(TARGET).elf
	$(OBJDUMP) -d -M no-aliases $< > $@

# Generate Verilog $readmemh format (32-bit words, starting from address 0)
$(TARGET).hex: $(TARGET).bin
	python3 bin2hex.py $< $@

clean:
	rm -f $(TARGET).elf $(TARGET).bin $(TARGET).hex $(TARGET).dis

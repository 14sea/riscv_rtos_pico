# Makefile — PicoRV32 ThreadX build
#
# Outputs: threadx.elf  threadx.hex  threadx.dis  threadx.bin

CROSS   := /home/test/xpack-riscv-none-elf-gcc-14.2.0-3/bin/riscv-none-elf-
CC      := $(CROSS)gcc
AS      := $(CROSS)gcc
LD      := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump

THREADX_DIR := ../../threadx-kernel

ARCH_FLAGS  := -march=rv32im -mabi=ilp32
OPT_FLAGS   := -Os -ffunction-sections -fdata-sections
WARN_FLAGS  := -Wall -Wno-unused-function -Wno-unused-variable
CFLAGS      := $(ARCH_FLAGS) $(OPT_FLAGS) $(WARN_FLAGS) \
               -nostdlib -ffreestanding \
               -DTX_INCLUDE_USER_DEFINE_FILE \
               -I. \
               -I$(THREADX_DIR)/common/inc

LDFLAGS     := $(ARCH_FLAGS) -nostdlib -nostartfiles \
               -T threadx.ld \
               -Wl,--no-relax \
               -Wl,--gc-sections \
               -Wl,-Map=threadx.map

# ---- Port-specific sources (this directory) ----
SRCS_C_PORT := \
    tx_thread_stack_build.c \
    main_threadx.c \
    syscalls.c

SRCS_S_PORT := \
    start_threadx.S \
    tx_irq_handler.S \
    tx_thread_system_return.S \
    tx_initialize_low_level.S \
    tx_timer_interrupt.S

# ---- ThreadX common kernel sources ----
TX_COMMON := $(THREADX_DIR)/common/src

SRCS_C_TX := \
    $(TX_COMMON)/tx_initialize_high_level.c \
    $(TX_COMMON)/tx_initialize_kernel_enter.c \
    $(TX_COMMON)/tx_initialize_kernel_setup.c \
    $(TX_COMMON)/tx_thread_create.c \
    $(TX_COMMON)/tx_thread_delete.c \
    $(TX_COMMON)/tx_thread_entry_exit_notify.c \
    $(TX_COMMON)/tx_thread_identify.c \
    $(TX_COMMON)/tx_thread_info_get.c \
    $(TX_COMMON)/tx_thread_initialize.c \
    $(TX_COMMON)/tx_thread_preemption_change.c \
    $(TX_COMMON)/tx_thread_priority_change.c \
    $(TX_COMMON)/tx_thread_relinquish.c \
    $(TX_COMMON)/tx_thread_reset.c \
    $(TX_COMMON)/tx_thread_resume.c \
    $(TX_COMMON)/tx_thread_shell_entry.c \
    $(TX_COMMON)/tx_thread_sleep.c \
    $(TX_COMMON)/tx_thread_suspend.c \
    $(TX_COMMON)/tx_thread_system_preempt_check.c \
    $(TX_COMMON)/tx_thread_system_resume.c \
    $(TX_COMMON)/tx_thread_system_suspend.c \
    $(TX_COMMON)/tx_thread_terminate.c \
    $(TX_COMMON)/tx_thread_time_slice.c \
    $(TX_COMMON)/tx_thread_time_slice_change.c \
    $(TX_COMMON)/tx_thread_timeout.c \
    $(TX_COMMON)/tx_thread_wait_abort.c \
    $(TX_COMMON)/tx_time_get.c \
    $(TX_COMMON)/tx_time_set.c \
    $(TX_COMMON)/tx_timer_activate.c \
    $(TX_COMMON)/tx_timer_change.c \
    $(TX_COMMON)/tx_timer_create.c \
    $(TX_COMMON)/tx_timer_deactivate.c \
    $(TX_COMMON)/tx_timer_delete.c \
    $(TX_COMMON)/tx_timer_expiration_process.c \
    $(TX_COMMON)/tx_timer_info_get.c \
    $(TX_COMMON)/tx_timer_initialize.c \
    $(TX_COMMON)/tx_timer_system_activate.c \
    $(TX_COMMON)/tx_timer_system_deactivate.c \
    $(TX_COMMON)/tx_timer_thread_entry.c \
    $(TX_COMMON)/tx_trace_disable.c

# ---- Object lists ----
OBJS_PORT := $(SRCS_C_PORT:.c=.o) $(SRCS_S_PORT:.S=.o)
OBJS_TX   := $(notdir $(SRCS_C_TX:.c=.o))

OBJS := $(OBJS_PORT) $(OBJS_TX)

.PHONY: all clean hex prog

all: threadx.hex threadx.dis

threadx.elf: $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $^
	@echo "=== Size ==="
	$(CROSS)size $@

threadx.bin: threadx.elf
	$(OBJCOPY) -O binary $< $@

threadx.hex: threadx.bin
	python3 ../bin2hex.py threadx.bin threadx.hex
	@echo "ROM usage: $$(wc -w < threadx.hex) words"

threadx.dis: threadx.elf
	$(OBJDUMP) -d -S $< > $@

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.S
	$(AS) $(CFLAGS) -c -o $@ $<

# ThreadX common sources — compile from source tree into current dir
%.o: $(TX_COMMON)/%.c
	$(CC) $(CFLAGS) -c -o $(notdir $@) $<

prog: threadx.hex
	@echo "Copying firmware.hex for Quartus..."
	cp threadx.hex ../../firmware.hex || cp threadx.hex ../../../firmware.hex

# ---- Fast-timer simulation build ----
# Timer = 5000 cycles (0.1ms per tick), sleeps = 2/3/5 ticks
SIM_CFLAGS := $(CFLAGS) -DTIMER_COUNTS=5000

sim/main_sim.o: main_threadx.c
	mkdir -p sim
	$(CC) $(SIM_CFLAGS) -c -o $@ \
	    -Dtx_thread_sleep\(50\)=tx_thread_sleep\(2\) \
	    -Dtx_thread_sleep\(100\)=tx_thread_sleep\(3\) \
	    -Dtx_thread_sleep\(200\)=tx_thread_sleep\(5\) \
	    $< 2>/dev/null || \
	    $(CC) $(SIM_CFLAGS) \
	    $(shell sed 's/sleep(50)/sleep(2)/g;s/sleep(100)/sleep(3)/g;s/sleep(200)/sleep(5)/g' $< > /tmp/_sim_main.c && echo "-c -o $@ /tmp/_sim_main.c")

threadx_sim.hex: $(filter-out main_threadx.o tx_irq_handler.o, $(OBJS))
	@echo "Building fast-timer simulation firmware..."
	# Recompile main with short sleeps
	sed 's/sleep(50)/sleep(2)/g;s/sleep(100)/sleep(3)/g;s/sleep(200)/sleep(5)/g' \
	    main_threadx.c > /tmp/_sim_main.c
	$(CC) $(SIM_CFLAGS) -c -o /tmp/_sim_main.o /tmp/_sim_main.c
	# Recompile IRQ handler with fast timer
	sed 's/TIMER_COUNTS.*500000/TIMER_COUNTS    5000/' \
	    tx_irq_handler.S > /tmp/_sim_irq.S
	$(AS) $(CFLAGS) -c -o /tmp/_sim_irq.o /tmp/_sim_irq.S
	$(LD) $(LDFLAGS) -o /tmp/_threadx_sim.elf \
	    tx_thread_stack_build.o /tmp/_sim_main.o syscalls.o start_threadx.o \
	    /tmp/_sim_irq.o tx_thread_system_return.o tx_initialize_low_level.o \
	    tx_timer_interrupt.o \
	    $(filter-out tx_thread_stack_build.o main_threadx.o syscalls.o \
	        start_threadx.o tx_irq_handler.o tx_thread_system_return.o \
	        tx_initialize_low_level.o tx_timer_interrupt.o, $(OBJS))
	$(OBJCOPY) -O binary /tmp/_threadx_sim.elf /tmp/_threadx_sim.bin
	python3 ../bin2hex.py /tmp/_threadx_sim.bin threadx_sim.hex
	cp threadx_sim.hex ../../sim/firmware.hex
	@echo "Simulation firmware ready in sim/"

clean:
	rm -f $(OBJS_PORT) $(OBJS_TX) \
	      threadx.elf threadx.bin threadx.hex threadx.dis threadx.map

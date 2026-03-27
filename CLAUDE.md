# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

PicoRV32 RV32IM soft-core SoC running on AX301 (EP4CE6F17C8 Cyclone IV E).
Three firmware targets: bare-metal smoke-test, FreeRTOS 11.1.0, and Eclipse ThreadX 6.4.1.

## Build Commands

### Bare-metal firmware (4 KB ROM)
```bash
cd firmware
make          # → firmware.hex
make clean
```

### FreeRTOS firmware (16 KB ROM)
```bash
cd firmware/freertos
make          # → freertos.hex  (~4900 bytes)
make clean
make prog     # copies freertos.hex → ../../firmware.hex
```

### ThreadX firmware (16 KB ROM)
```bash
cd firmware/threadx
make          # → threadx.hex  (~6000 bytes)
make clean
make prog     # copies threadx.hex → ../../firmware.hex

# Fast-timer simulation build (TIMER_COUNTS=5000, short sleeps for quick preemption test):
make threadx_sim.hex   # → sim/firmware.hex (ready for vvp tb_soc)
```

### Quartus synthesis + program
```bash
export PATH=$PATH:$HOME/intelFPGA_lite/21.1/quartus/bin
cd quartus
# Copy the desired firmware first:
make -C ../firmware/freertos prog   # or threadx, or bare-metal

quartus_sh --flow compile riscv_demo
quartus_cpf -c -o bitstream_compression=off output_files/riscv_demo.sof riscv_demo.rbf
../../openFPGALoader/build/openFPGALoader -c usb-blaster riscv_demo.rbf
```

### Icarus Verilog simulation
```bash
cd sim
# Compile (needed after RTL changes):
iverilog -o tb_soc tb_soc.v ../rtl/soc_top.v ../rtl/picorv32.v \
         ../rtl/sdram_ctrl.v ../rtl/uart_periph.v \
         -I../rtl -DSIM

# sim/firmware.hex is read at runtime (no recompile needed when firmware changes):
cp ../firmware/threadx/threadx_sim.hex firmware.hex
vvp tb_soc   # default 20 ms window; edit #20_000_000 to extend
```

## Architecture

### Memory Map
| Base | Size | Device |
|------|------|--------|
| `0x00000000` | 16 KB | Boot ROM (M9K BRAM, `$readmemh("firmware.hex")`) |
| `0x20000000` | 8 KB | SRAM (M9K BRAM, 4 byte-wide banks for byte-write) |
| `0x40000000` | 32 MB | SDRAM HY57V2562GTR (external, via `sdram_ctrl.v`) |
| `0x80000000` | 16 B | UART: +0=TX/RX, +4=RX alias, +8=status (bit0=TXrdy, bit1=RXrdy) |

### CPU configuration (`rtl/soc_top.v`)
```
ENABLE_MUL=1, ENABLE_DIV=1, ENABLE_IRQ=1, ENABLE_IRQ_TIMER=1
PROGADDR_RESET=0x00000000, PROGADDR_IRQ=0x00000010, STACKADDR=0x20002000
```

IRQ bit assignments:
- bit 0 — timer countdown (via `timer` custom instruction)
- bit 1 — ecall/ebreak (**reserved for RTOS yield** — never wire external IRQ here)
- bit 2 — bus error
- bit 3+ — external (`irq[]` input); UART RX is on bit 3

### PicoRV32 Custom IRQ Instructions (opcode `0x0B`)
| Instruction | Encoding (a0/x10) | Description |
|-------------|-------------------|-------------|
| `getq rd, q0` | `0x0000050B` | rd ← interrupted PC |
| `getq rd, q1` | `0x0000850B` | rd ← IRQ bitmap (`irq_pending & ~irq_mask`) |
| `setq q0, rs` | `0x0205000B` (rs=a0) | q0 ← rs (set return PC before retirq) |
| `maskirq rd, rs` | `0x0605050B` (rd=rs=a0) | rd←old_mask; irq_mask←rs |
| `maskirq x0, x0` | `0x0600000B` | enable all IRQs (irq_mask=0) |
| `timer rd, rs` | `0x0A05050B` (rd=rs=a0) | rd←old_timer; countdown←rs |
| `retirq` | `0x0400000B` | jump to q0; irq_active←0 |

On IRQ entry: q0 ← interrupted PC, q1 ← `(irq_pending & ~irq_mask)`.
**retirq does NOT restore irq_mask** — only restores PC and clears `irq_active`.
While `irq_active=1`, no new IRQ can fire (non-reentrant).

### BRAM Inference Rules (Quartus M9K)
- ROM read: must be `always @(posedge clk)` with **no reset** on the data register.
- SRAM write: 4 separate byte-wide banks (`reg [7:0] sramN [0:2047]`) for byte-enable writes.
- Violating either pattern causes Quartus to infer flip-flops → 120K+ LE explosion.

### Context Frame (shared by FreeRTOS and ThreadX ports)
128 bytes (32 words, 16-byte aligned):
- Slots 0–29: x1, x3–x31 (30 GP registers; x2/sp implicit, x0 always zero)
- Slot 30 (offset `0x78`): PC (from q0 on IRQ entry; loaded into q0 before retirq)
- Slot 31: padding

---

## FreeRTOS Port (`firmware/freertos/`)

| File | Role |
|------|------|
| `FreeRTOSConfig.h` | 100 Hz tick, 4 KB heap, 5 priorities |
| `portmacro.h` | Types + `portDISABLE/ENABLE_INTERRUPTS` via `maskirq` |
| `portASM.S` | IRQ handler + `xPortStartFirstTask` |
| `port.c` | `pxPortInitialiseStack`, `xPortStartScheduler`, `vPortSetupTimerInterrupt` |
| `start_freertos.S` | Reset vector (0x00) + IRQ vector jump (0x10) + BSS/data init |
| `syscalls.c` | `memset`, `memcpy`, `__clzsi2` |

`pxCurrentTCB->pxTopOfStack` (TCB **offset 0**) always points to the bottom of the active context frame.

`_freertos_irq_handler` flow:
1. `addi sp, sp, -128` → allocate frame
2. Save x1,x3–x31; `getq a0,q0` → save PC at slot 30
3. `getq a0,q1` → IRQ bitmap
4. `sw sp, 0(pxCurrentTCB)` → save task sp
5. bit0=timer: reload timer, call `xTaskIncrementTick`; bit1=yield: call `vTaskSwitchContext`
6. Reload sp from (possibly new) `pxCurrentTCB->pxTopOfStack`
7. `lw a0, 0x78(sp)` → `setq q0, a0`; restore regs; `retirq`

`portYIELD()` = `ecall` → triggers IRQ bit 1.

---

## ThreadX Port (`firmware/threadx/`)

Eclipse ThreadX v6.4.1_rel. The kernel sources live in `threadx-kernel/common/src/`. No GCC port existed upstream; this is a custom GCC port written using the IAR RISC-V32 port as reference.

| File | Role |
|------|------|
| `tx_port.h` | Port types, `TX_DISABLE`/`TX_RESTORE` via `maskirq` |
| `tx_user.h` | Config: `TX_TIMER_PROCESS_IN_ISR`, 100 Hz tick, 500000-cycle timer |
| `start_threadx.S` | Reset vector (0x00) + IRQ vector jump (0x10) + BSS/data init |
| `tx_irq_handler.S` | IRQ dispatcher, context save/restore, `_tx_thread_schedule` |
| `tx_thread_system_return.S` | `_tx_thread_system_return` = `ecall` (yield) |
| `tx_initialize_low_level.S` | Sets `_tx_initialize_unused_memory`, `_tx_thread_system_stack_ptr` |
| `tx_timer_interrupt.S` | `_tx_timer_interrupt` ported from IAR assembly to GCC syntax |
| `tx_thread_stack_build.c` | Builds initial 128-byte context frame for new threads |
| `syscalls.c` | `memset`, `memcpy`, `__clzsi2` (needed for priority bitmaps) |

**TCB field offsets** (differ from FreeRTOS):
- offset 4: `tx_thread_run_count`
- offset 8: `tx_thread_stack_ptr` ← sp saved here (NOT offset 0)
- offset 16: `tx_thread_stack_end` (highest address of stack buffer)
- offset 24: `tx_thread_time_slice`

**`_tx_threadx_irq_handler` flow:**
1. `addi sp, sp, -128` → allocate frame; save all GP regs + PC (slot 30)
2. Check `_tx_thread_current_ptr`: NULL → idle was running; non-NULL → thread running
3. Save sp to `TCB->tx_thread_stack_ptr` (offset 8)
4. Dispatch: bit0=timer (reload timer, **increment `_tx_thread_system_state`**, call `_tx_timer_interrupt`, decrement); bit1=yield (ThreadX C already updated execute_ptr)
5. Load `execute_ptr` → update `current_ptr`; switch sp to new thread's `tx_thread_stack_ptr`
6. `setq q0, PC`; restore regs; `retirq`

**Critical: `_tx_thread_system_state` guard.** Before calling `_tx_timer_interrupt()` from the ISR, increment `_tx_thread_system_state` to 1 (ISR context). Without this, `_tx_thread_system_preempt_check` sees thread context (state=0) and issues `ecall` to yield — but `irq_active=1` blocks the ecall IRQ → CPU trap.

**Idle thread requirement.** Always create a lowest-priority (priority 31) idle thread that never sleeps. If all user threads sleep simultaneously, `_tx_thread_execute_ptr` would become NULL, causing a NULL-dereference in `_irq_exit`. The idle thread prevents this.

`_tx_thread_stack_build` places the context frame at `(stack_end & ~0xF) - 128`. `stack_end` = `stack_start + stack_size - 1` (set by `tx_thread_create`).

`TX_DISABLE` macro uses `{...};` syntax (semicolon inside macro) because ThreadX calls it without a trailing semicolon.

---

## Known Pitfalls

1. **retirq encoding**: `0x0400000B` (funct7=2). `0x0C00000B` (funct7=6) is wrong — assembles silently but not recognised by RTL.

2. **irq[1] is reserved**: External `irq[1]` input collides with ecall/ebreak (bit 1). Never wire external signals to irq[1].

3. **`_tx_thread_system_state` guard**: Must be incremented before any C call from the timer ISR that could trigger `_tx_thread_system_preempt_check`. See ThreadX port section above.

4. **No idle thread → NULL crash**: ThreadX's `_tx_thread_execute_ptr` goes NULL when all threads sleep. Always include a lowest-priority idle thread.

5. **bin2hex.py takes `.bin`, not `.elf`**: Always run `objcopy -O binary` first.

6. **Power-on reset**: PicoRV32 needs an explicit reset pulse. `soc_top.v` uses a 16-cycle POR counter gated with KEY2.

7. **ROM size**: `soc_top.v` is set to 16 KB (`[0:4095]`). Both RTOS builds fit well within this. Do not shrink it back to 4 KB without updating the address decode (`mem_addr[13:2]`).

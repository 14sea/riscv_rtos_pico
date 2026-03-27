# PicoRV32 + FreeRTOS / ThreadX (AX301 / Cyclone IV)

PicoRV32 soft-core SoC on AX301 with two RTOS firmware options: FreeRTOS and ThreadX.

## Hardware Target

- Board: Heijin AX301
- FPGA: Altera Cyclone IV EP4CE6F17C8

## Project Layout

- `rtl/`: PicoRV32 SoC RTL
- `quartus/`: Quartus project and constraints
- `firmware/`: bare-metal/RTOS firmware builds
- `FreeRTOS-Kernel-11.1.0/`: vendored FreeRTOS kernel
- `threadx-kernel/`: vendored ThreadX kernel
- `sim/`: simulation testbench files

## Prerequisites

- Quartus Prime Lite
- RISC-V GCC (`riscv-none-elf-*`)
- Python 3 (for `bin2hex.py`)
- `openFPGALoader`

## Build Firmware

```bash
# FreeRTOS image
cd firmware/freertos
make

# ThreadX image
cd ../threadx
make
```

## Build FPGA Bitstream

```bash
cd ../../quartus
cp ../firmware/freertos/freertos.hex firmware.hex   # or use threadx/threadx.hex
quartus_sh --flow compile riscv_demo
quartus_cpf -c -o bitstream_compression=off output_files/riscv_demo.sof riscv_demo.rbf
```

## Program Board

```bash
openFPGALoader -c usb-blaster quartus/riscv_demo.rbf
```

## Notes

- `firmware.hex` is an input artifact generated from selected firmware and should not be versioned.
- Large waveform files (for example `sim/tb_soc.vcd`) should stay outside git.

/*
 * Copyright (c) 2026
 *
 * Licensed under the MIT License.
 * See LICENSE file in the project root for full license information.
 */

// PicoRV32 SoC Top Level for AX301 (EP4CE6F17C8)
//
// Memory map:
//   0x00000000 - 0x00003FFF : Boot ROM  (16 KB, BRAM)
//   0x20000000 - 0x20001FFF : SRAM      ( 8 KB, BRAM)
//   0x40000000 - 0x41FFFFFF : SDRAM     (32 MB, external)
//   0x80000000 - 0x8000000F : UART      (TX/RX/Status)
//
// PicoRV32 config: RV32IM, IRQ enabled (for FreeRTOS timer tick)
// IRQ bits: 0=timer (internal), 1=ecall/ebreak (portYIELD), 2=bus-error

module soc_top (
    input         CLOCK,       // 50 MHz
    input         KEY2,        // active-low reset button

    // UART
    input         RXD,
    output        TXD,

    // LEDs (active low)
    output [3:0]  LED,

    // SDRAM
    output        S_CLK,
    output        S_CKE,
    output        S_NCS,
    output        S_NRAS,
    output        S_NCAS,
    output        S_NWE,
    output [ 1:0] S_BA,
    output [12:0] S_A,
    output [ 1:0] S_DQM,
    inout  [15:0] S_DB
);

    wire clk = CLOCK;

    // Power-on reset: hold reset low for 16 cycles after configuration
    reg [3:0] por_cnt = 4'd0;
    always @(posedge clk)
        if (!por_cnt[3]) por_cnt <= por_cnt + 4'd1;

    wire rst_n = KEY2 & por_cnt[3];  // combine button + POR

    // =============== PicoRV32 CPU ===============
    wire        mem_valid;
    wire        mem_instr;
    wire        mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [ 3:0] mem_wstrb;
    wire [31:0] mem_rdata;
    wire        trap;
    wire [31:0] irq;
    wire [31:0] eoi;

    picorv32 #(
        .ENABLE_COUNTERS   (0),
        .ENABLE_COUNTERS64 (0),
        .ENABLE_MUL        (1),
        .ENABLE_DIV        (1),
        .ENABLE_IRQ        (1),
        .ENABLE_IRQ_TIMER  (1),
        .BARREL_SHIFTER    (0),
        .COMPRESSED_ISA    (0),
        .PROGADDR_RESET    (32'h 0000_0000),
        .PROGADDR_IRQ      (32'h 0000_0010),
        .STACKADDR         (32'h 2000_2000)  // top of 8 KB SRAM
    ) cpu (
        .clk       (clk),
        .resetn    (rst_n),
        .trap      (trap),

        .mem_valid (mem_valid),
        .mem_instr (mem_instr),
        .mem_ready (mem_ready),
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wstrb (mem_wstrb),
        .mem_rdata (mem_rdata),

        .mem_la_read  (),
        .mem_la_write (),
        .mem_la_addr  (),
        .mem_la_wdata (),
        .mem_la_wstrb (),

        .pcpi_valid (),
        .pcpi_insn  (),
        .pcpi_rs1   (),
        .pcpi_rs2   (),
        .pcpi_wr    (1'b0),
        .pcpi_rd    (32'd0),
        .pcpi_wait  (1'b0),
        .pcpi_ready (1'b0),

        .irq (irq),
        .eoi (eoi),

        .trace_valid (),
        .trace_data  ()
    );

    // =============== Address decode ===============
    // mem_addr[31:28]:
    //   0x0 → ROM
    //   0x2 → SRAM
    //   0x4 → SDRAM
    //   0x8 → I/O (UART)

    wire sel_rom  = mem_valid && (mem_addr[31:28] == 4'h0);
    wire sel_sram = mem_valid && (mem_addr[31:28] == 4'h2);
    wire sel_sdram= mem_valid && (mem_addr[31:28] == 4'h4);
    wire sel_uart = mem_valid && (mem_addr[31:28] == 4'h8);

    wire [31:0] rom_rdata, sram_rdata, sdram_rdata, uart_rdata;
    wire        rom_ready, sram_ready, sdram_ready, uart_ready;

    assign mem_ready = rom_ready | sram_ready | sdram_ready | uart_ready;
    assign mem_rdata = rom_ready  ? rom_rdata  :
                       sram_ready ? sram_rdata :
                       sdram_ready? sdram_rdata:
                       uart_ready ? uart_rdata :
                       32'h 0000_0000;

    // =============== Boot ROM (16 KB, read-only) ===============
    // Coded for Quartus M9K inference: simple clocked read, no async reset on data
    reg [31:0] rom [0:4095];  // 4096 × 32 = 16 KB
    initial $readmemh("firmware.hex", rom);

    reg [31:0] rom_rdata_r;
    always @(posedge clk)
        rom_rdata_r <= rom[mem_addr[13:2]];  // 14-bit address for 4K entries

    reg rom_ready_r;
    always @(posedge clk or negedge rst_n)
        if (!rst_n)    rom_ready_r <= 1'b0;
        else           rom_ready_r <= sel_rom && !rom_ready_r;

    assign rom_rdata = rom_rdata_r;
    assign rom_ready = rom_ready_r;

    // =============== SRAM (8 KB, read/write) ===============
    // 4 byte-wide banks for Quartus M9K inference with byte-write support
    reg [7:0] sram0 [0:2047];  // byte 0
    reg [7:0] sram1 [0:2047];  // byte 1
    reg [7:0] sram2 [0:2047];  // byte 2
    reg [7:0] sram3 [0:2047];  // byte 3

    wire [10:0] sram_addr = mem_addr[12:2];
    wire sram_wen = sel_sram && (mem_wstrb != 4'b0000);

    reg [31:0] sram_rdata_r;
    always @(posedge clk) begin
        if (sram_wen && mem_wstrb[0]) sram0[sram_addr] <= mem_wdata[ 7: 0];
        if (sram_wen && mem_wstrb[1]) sram1[sram_addr] <= mem_wdata[15: 8];
        if (sram_wen && mem_wstrb[2]) sram2[sram_addr] <= mem_wdata[23:16];
        if (sram_wen && mem_wstrb[3]) sram3[sram_addr] <= mem_wdata[31:24];
        sram_rdata_r <= {sram3[sram_addr], sram2[sram_addr],
                         sram1[sram_addr], sram0[sram_addr]};
    end

    reg sram_ready_r;
    always @(posedge clk or negedge rst_n)
        if (!rst_n)    sram_ready_r <= 1'b0;
        else           sram_ready_r <= sel_sram && !sram_ready_r;

    assign sram_rdata = sram_rdata_r;
    assign sram_ready = sram_ready_r;

    // =============== SDRAM ===============
    wire sdram_init_done;

    sdram_ctrl sdram_inst (
        .clk       (clk),
        .rst_n     (rst_n),
        .sel       (sel_sdram),
        .addr      (mem_addr[24:0]),
        .wdata     (mem_wdata),
        .wstrb     (mem_wstrb),
        .rdata     (sdram_rdata),
        .ready     (sdram_ready),
        .sdram_clk (S_CLK),
        .sdram_cke (S_CKE),
        .sdram_cs_n(S_NCS),
        .sdram_ras_n(S_NRAS),
        .sdram_cas_n(S_NCAS),
        .sdram_we_n(S_NWE),
        .sdram_ba  (S_BA),
        .sdram_addr(S_A),
        .sdram_dqm (S_DQM),
        .sdram_dq  (S_DB),
        .init_done (sdram_init_done)
    );

    // =============== UART ===============
    wire uart_irq;

    uart_periph uart_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .sel      (sel_uart),
        .addr     (mem_addr[3:0]),
        .wdata    (mem_wdata),
        .wstrb    (mem_wstrb),
        .rdata    (uart_rdata),
        .ready    (uart_ready),
        .uart_rxd (RXD),
        .uart_txd (TXD),
        .irq_rx   (uart_irq)
    );

    // =============== IRQ ===============
    // PicoRV32 IRQ mapping (bits 0-2 are reserved for built-in events):
    //   bit 0 = timer countdown (internal, via `timer` instruction)
    //   bit 1 = ecall/ebreak   (internal, fires on ECALL → portYIELD)
    //   bit 2 = bus error      (internal)
    //   bit 3 = UART RX        (external)
    // NOTE: do NOT put UART on bit 1 — that conflicts with portYIELD (ecall).
    assign irq = {28'd0, uart_irq, 3'd0};  // uart_irq on bit 3

    // =============== LEDs ===============
    // Active-low: LED on when output is 0
    // LED[0] = heartbeat (blink), LED[1] = SDRAM init done
    // LED[2] = ~trap, LED[3] = UART TX active
    reg [23:0] heartbeat;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            heartbeat <= 24'd0;
        else
            heartbeat <= heartbeat + 24'd1;
    end

    assign LED[0] = ~heartbeat[23];       // ~1.5 Hz blink
    assign LED[1] = ~sdram_init_done;
    assign LED[2] = trap;                  // LED on when no trap
    assign LED[3] = 1'b1;                  // off

endmodule

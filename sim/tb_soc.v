// Testbench for PicoRV32 SoC
// Simulates boot and UART output

`timescale 1ns / 1ps

module tb_soc;

    reg clk, rst_n;
    wire txd;
    wire [3:0] led;

    // SDRAM signals (active but not fully modeled in sim)
    wire        s_clk, s_cke, s_ncs, s_nras, s_ncas, s_nwe;
    wire [1:0]  s_ba, s_dqm;
    wire [12:0] s_a;
    wire [15:0] s_db;

    // Pulldown SDRAM data bus (no SDRAM model in sim)
    assign s_db = 16'hzzzz;

    soc_top uut (
        .CLOCK (clk),
        .KEY2  (rst_n),
        .RXD   (1'b1),    // idle high
        .TXD   (txd),
        .LED   (led),
        .S_CLK (s_clk),
        .S_CKE (s_cke),
        .S_NCS (s_ncs),
        .S_NRAS(s_nras),
        .S_NCAS(s_ncas),
        .S_NWE (s_nwe),
        .S_BA  (s_ba),
        .S_A   (s_a),
        .S_DQM (s_dqm),
        .S_DB  (s_db)
    );

    // 50 MHz clock
    initial clk = 0;
    always #10 clk = ~clk;

    // UART receiver (capture TX output for display)
    localparam BAUD_TICKS = 434;  // 50 MHz / 115200
    reg [7:0]  uart_rx_byte;
    reg [3:0]  uart_rx_cnt;
    reg [15:0] uart_rx_timer;
    reg        uart_rx_active;
    reg        txd_prev;
    integer    char_count;

    initial begin
        uart_rx_active = 0;
        uart_rx_cnt = 0;
        uart_rx_timer = 0;
        char_count = 0;
        txd_prev = 1;
    end

    always @(posedge clk) begin
        txd_prev <= txd;

        if (uart_rx_active) begin
            if (uart_rx_timer >= BAUD_TICKS - 1) begin
                uart_rx_timer <= 0;
                if (uart_rx_cnt == 0) begin
                    // First fire = mid-start-bit: skip
                    uart_rx_cnt <= 1;
                end else if (uart_rx_cnt >= 9) begin
                    // Stop bit — output the received character
                    uart_rx_active <= 0;
                    if (uart_rx_byte >= 8'h20 && uart_rx_byte < 8'h7F)
                        $write("%c", uart_rx_byte);
                    else if (uart_rx_byte == 8'h0A)
                        $write("\n");
                    else if (uart_rx_byte == 8'h0D)
                        ; // skip CR
                    else
                        $write("[0x%02x]", uart_rx_byte);
                    char_count <= char_count + 1;
                end else begin
                    // Data bits: cnt 1→data[0], 2→data[1], ..., 8→data[7]
                    uart_rx_byte[uart_rx_cnt - 1] <= txd;
                    uart_rx_cnt <= uart_rx_cnt + 1;
                end
            end else begin
                uart_rx_timer <= uart_rx_timer + 1;
            end
        end else if (txd_prev && !txd) begin
            // Falling edge = start bit
            uart_rx_active <= 1;
            uart_rx_cnt <= 0;
            uart_rx_timer <= BAUD_TICKS / 2;  // first fire at mid-start-bit
            uart_rx_byte <= 0;
        end
    end

    // Monitor trap signal
    always @(posedge clk) begin
        if (uut.trap) begin
            $display("\n[TRAP at time %0t] CPU halted!", $time);
            #1000;
            $finish;
        end
    end

    // Simulation control
    initial begin
        $dumpfile("tb_soc.vcd");
        $dumpvars(0, tb_soc);

        rst_n = 0;
        repeat (5) @(posedge clk);
        rst_n = 1;

        // Run for enough time to see UART output
        // At 115200 baud, each char ≈ 87 µs ≈ 4340 cycles
        // ~80 chars of output → ~350,000 cycles → 7 ms
        #20_000_000;  // 20 ms

        $display("\n[SIM] Simulation ended after 20 ms (%0d chars received)", char_count);
        $finish;
    end

endmodule

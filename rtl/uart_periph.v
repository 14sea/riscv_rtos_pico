/*
 * Copyright (c) 2026
 *
 * Licensed under the MIT License.
 * See LICENSE file in the project root for full license information.
 */

// Memory-mapped UART peripheral (115200 baud, 8N1, 50 MHz clock)
//
// Register map:
//   offset 0x0: TXDATA  — write: send byte[7:0]; read: 0
//   offset 0x4: RXDATA  — read: received byte (clears rx_valid); write: ignored
//   offset 0x8: STATUS  — bit 0: TX ready, bit 1: RX data available

module uart_periph (
    input             clk,
    input             rst_n,

    // CPU bus interface
    input             sel,
    input      [ 3:0] addr,     // byte offset
    input      [31:0] wdata,
    input      [ 3:0] wstrb,
    output reg [31:0] rdata,
    output reg        ready,

    // UART pins
    input             uart_rxd,
    output reg        uart_txd,

    // IRQ (active high when RX data available)
    output            irq_rx
);

    localparam BAUD_DIV = 434;  // 50 MHz / 115200

    // ===================== TX =====================
    reg [9:0]  tx_frame;     // {stop, d7..d0, start}
    reg [3:0]  tx_cnt;       // bit index 0-9
    reg [15:0] tx_timer;
    reg        tx_active;

    wire tx_start = sel && (wstrb != 4'b0000) && (addr[3:2] == 2'b00) && !tx_active;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_cnt    <= 4'd0;
            tx_timer  <= 16'd0;
            tx_active <= 1'b0;
            uart_txd  <= 1'b1;
            tx_frame  <= 10'h3FF;
        end else if (tx_active) begin
            if (tx_timer >= BAUD_DIV - 1) begin
                tx_timer <= 16'd0;
                if (tx_cnt >= 4'd9) begin
                    tx_active <= 1'b0;
                    uart_txd  <= 1'b1;
                end else begin
                    tx_cnt   <= tx_cnt + 4'd1;
                    uart_txd <= tx_frame[tx_cnt + 1];
                end
            end else begin
                tx_timer <= tx_timer + 16'd1;
            end
        end else if (tx_start) begin
            tx_frame  <= {1'b1, wdata[7:0], 1'b0};  // {stop, data, start}
            tx_cnt    <= 4'd0;
            tx_timer  <= 16'd0;
            tx_active <= 1'b1;
            uart_txd  <= 1'b0;  // start bit immediately
        end
    end

    // ===================== RX =====================
    reg [7:0]  rx_data;
    reg        rx_valid;
    reg [3:0]  rx_bit_cnt;
    reg [15:0] rx_timer;
    reg        rx_active;
    reg [1:0]  rx_sync;

    wire rx_pin = rx_sync[1];
    wire rx_read = sel && (wstrb == 4'b0000) && (addr[3:2] == 2'b01);

    assign irq_rx = rx_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rx_sync <= 2'b11;
        else
            rx_sync <= {rx_sync[0], uart_rxd};
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_data    <= 8'd0;
            rx_valid   <= 1'b0;
            rx_bit_cnt <= 4'd0;
            rx_timer   <= 16'd0;
            rx_active  <= 1'b0;
        end else begin
            if (rx_read)
                rx_valid <= 1'b0;

            if (rx_active) begin
                if (rx_timer >= BAUD_DIV - 1) begin
                    rx_timer <= 16'd0;
                    if (rx_bit_cnt == 4'd0) begin
                        // First fire = mid-start-bit; skip (verify start low)
                        rx_bit_cnt <= 4'd1;
                    end else if (rx_bit_cnt >= 4'd9) begin
                        // Stop bit
                        rx_active <= 1'b0;
                        if (rx_pin) rx_valid <= 1'b1;
                    end else begin
                        rx_data[rx_bit_cnt[2:0] - 1] <= rx_pin;
                        rx_bit_cnt <= rx_bit_cnt + 4'd1;
                    end
                end else begin
                    rx_timer <= rx_timer + 16'd1;
                end
            end else if (!rx_pin) begin
                // Falling edge = start bit
                rx_active  <= 1'b1;
                rx_bit_cnt <= 4'd0;
                rx_timer   <= BAUD_DIV / 2;  // first fire at mid-start-bit
            end
        end
    end

    // ===================== Bus read =====================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata <= 32'd0;
            ready <= 1'b0;
        end else begin
            ready <= 1'b0;
            if (sel) begin
                ready <= 1'b1;
                case (addr[3:2])
                    2'b00: rdata <= 32'd0;
                    2'b01: rdata <= {24'd0, rx_data};
                    2'b10: rdata <= {30'd0, rx_valid, ~tx_active};
                    default: rdata <= 32'd0;
                endcase
            end
        end
    end

endmodule

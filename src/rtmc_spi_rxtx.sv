/*
 * Copyright (c) 2024 J. R. Petrus
 * SPDX-License-Identifier: Apache-2.0
 */

// Low-level SPI interface.
// Shifts 1 byte at a time.
// SCK period must be at least 2x clk period.
// No FIFOs nor CDC for low logic utilization.
// CPOL = 0, CPHA = 0

module rtmc_spi_rxtx #(
    // Word width to shift in/out.
    parameter N_BITS = 8
)
(
    // Core clock and reset
    input  logic clk,
    input  logic rst_n,

    // SPI interface to pins
    input  logic sck,
    input  logic cs_n,
    input  logic sdi,
    output logic sdo,

    // Rx Data
    output logic[N_BITS-1:0] din,
    output logic din_valid,

    // Tx Data
    input  logic[N_BITS-1:0] dout,
    input  logic dout_valid,
    output logic dout_ack
);
    // Clock Edge detection and input regs.
    logic sck_r0, sck_r1;
    logic sck_edge;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            {sck_r1, sck_r0} <= '0;
        end
        else begin
            {sck_r1, sck_r0} <= cs_n ? '0 : {sck_r0, sck};
        end
    end

    assign sck_edge = sck_r0 & ~sck_r1;

    // Bit counter for byte-oriented 
    logic [$clog2(N_BITS)-1:0] bit_count;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            bit_count <= '1;
        end
        else begin
            bit_count <= cs_n ? '1 : sck_edge ? bit_count - 'd1 : bit_count;
        end
    end

    // Shift data in.
    logic sdi_r;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            din_valid <= '0;
        end
        else begin
            din_valid <= '0;
            sdi_r <= sdi;
            if(sck_edge) begin
                din <= {din[$left(din)-1:0], sdi_r};
                din_valid <= ~|bit_count;
            end
        end
    end

    // Shift data out.
    logic [7:0] dout_r;

    assign sdo = dout_r[$left(dout_r)];

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            dout_r <= '0;
            dout_ack <= '0;
        end
        else begin
            dout_ack <= '0;
            if(cs_n) begin
                dout_r <= '0;
            end
            else begin
                if(&bit_count && !sck_edge) begin
                    dout_r <= dout_valid ? dout : '0;
                end

                if(sck_edge) begin
                    dout_ack <= &bit_count & dout_valid; // & ~dout_ack;
                    dout_r <= {dout_r[$left(dout_r)-1:0], 1'b0};
                end
            end
        end
    end

endmodule

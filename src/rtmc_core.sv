/*
 * Copyright (c) 2024 J. R. Petrus
 * SPDX-License-Identifier: Apache-2.0
 */

module rtmc_core #(
    parameter ADDR_W = 8,
    parameter DATA_W = 16,
    parameter MC_W = 4
)
(
    input  logic clk,
    input  logic rst_n,

    // SPI interface.
    input  logic sck,
    input  logic cs_n,
    input  logic sdi,
    output logic sdo,

    // GPIO.
    input  logic [3:0] gpi,
    output logic [3:0] gpo,

    // Stepper motors.
    output logic [MC_W-1:0] mc,
    output logic [MC_W-1:0] mc_oe
);
    // Reset synchronization.
    logic meta_rst_n;
    logic sync_rst_n;

    // Register bus.
    logic [ADDR_W-1:0] reg_addr;
    logic [DATA_W-1:0] reg_wdat;
    logic reg_wr;
    logic reg_rd;
    logic [DATA_W-1:0] reg_rdat;
    logic reg_ack;

    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            meta_rst_n <= '0;
            sync_rst_n <= '0;
        end
        else begin
            meta_rst_n <= '1;
            sync_rst_n <= meta_rst_n;
        end;
    end

    rtmc_spi spi(
        .rst_n(sync_rst_n),
        .*
    );

    rtmc_ctrl ctrl(
        .rst_n(sync_rst_n),
        .*
    );

endmodule

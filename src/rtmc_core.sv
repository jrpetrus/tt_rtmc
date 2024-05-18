/*
 * Copyright (c) 2024 J. R. Petrus
 * SPDX-License-Identifier: Apache-2.0
 */

import rtmc_pkg::*;

module rtmc_core(
    input  logic ena,
    input  logic clk,
    input  logic rst_n,

    // SPI interface.
    input  logic sck,
    input  logic cs_n,
    input  logic sdi,
    output logic sdo,

    // GPIO.
    input  logic [13:0] gpi,
    output logic [6:0] gpo,

    // Stepper motors.
    output logic [7:0] mc,
    output logic [7:0] mc_oe
);
    // Reset synchronization
    logic meta_rst_n;
    logic sync_rst_n;

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

    // Temporary Empty register bus.
    logic [ADDR_W-1:0] reg_addr;
    logic [DATA_W-1:0] reg_wdat;
    logic reg_wr;
    logic reg_rd;
    logic [DATA_W-1:0] reg_rdat;
    logic reg_ack;  
    logic [DATA_W-1:0] regfile[0:2**ADDR_W-1];

    always_ff @(posedge clk or negedge sync_rst_n) begin
        if(!sync_rst_n) begin
            reg_ack <= '0;
        end
        else begin
            if(reg_wr)
                regfile[reg_addr] <= reg_wdat;

            if(reg_rd) 
                reg_rdat <= regfile[reg_addr];

            if(reg_wr || reg_rd) 
                reg_ack <= ~reg_ack;
            else
                reg_ack <= '0;
        end 
    end

endmodule
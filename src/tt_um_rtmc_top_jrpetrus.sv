/*
 * Copyright (c) 2024 J. R. Petrus
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_rtmc_top_jrpetrus (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
    assign uio_out[7:4] = '0;
    assign uio_oe[7:4] = '0;
    assign uo_out[6:4] = '0;

    rtmc_core core(
        .sck(ui_in[5]),
        .cs_n(ui_in[6]),
        .sdi(ui_in[7]),
        .sdo(uo_out[7]),
        .gpi({ui_in[3:0]}),
        .gpo(uo_out[3:0]),
        .mc(uio_out[3:0]),
        .mc_oe(uio_oe[3:0]),
        .*
    );

endmodule

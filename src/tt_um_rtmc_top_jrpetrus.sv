/*
 * Copyright (c) 2024 J. R. Petrus
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

/*
Inputs
ui[0]: "General Purpose Input gpi[0]"
ui[1]: "General Purpose Input gpi[1]"
ui[2]: "General Purpose Input gpi[2]"
ui[3]: "General Purpose Input gpi[3]"
ui[4]: "SPI0.cs"
ui[5]: "SPI0.sck"
ui[6]: "SPI0.tx"
ui[7]: "Connected to uo[6]"

Outputs
uo[0]: "General Purpose Output gpo[0]"
uo[1]: "General Purpose Output gpo[1]"
uo[2]: "General Purpose Output gpo[2]"
uo[3]: "General Purpose Output gpo[3]"
uo[4]: "Connected to ^uio_in"
uo[5]: "Connected to ui[7]"
uo[6]: "Connected to ena"
uo[7]: "SPI0.rx"

Bidirectional pins
uio[0]: "Motor Control mc[0]"
uio[1]: "Motor Control mc[1]"
uio[2]: "Motor Control mc[2]"
uio[3]: "Motor Control mc[3]"
uio[4]: "Motor Control mc[4]"
uio[5]: "Motor Control mc[5]"
uio[6]: "Motor Control mc[6]"
uio[7]: "Motor Control mc[7]"
*/

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
    // Tie-off and prevent lint warnings.
    assign uo_out[6] = ena;
    assign uo_out[5] = ui_in[7];
    assign uo_out[4] = ^uio_in;

    rtmc_core core(
        .sck(ui_in[5]),
        .cs_n(ui_in[4]),
        .sdi(ui_in[6]),
        .sdo(uo_out[7]),
        .gpi({ui_in[3:0]}),
        .gpo(uo_out[3:0]),
        .mc(uio_out),
        .mc_oe(uio_oe),
        .*
    );

endmodule

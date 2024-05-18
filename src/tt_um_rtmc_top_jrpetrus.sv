/*
 * Copyright (c) 2024 J. R. Petrus
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

import rtmc_pkg::*;

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

    // ----------------------------------
    // Pin Mapping
    // ----------------------------------

    // --- SPI Interface ---
    // sclk: ui_in[5]  SPI Clock
    // cs_n: ui_in[6]  SPI Chip Select
    // sdi: ui_in[7]   Serial Data In
    // sdo: uo_out[7]  Serial Data Out

    // --- Stepper Motor Control Pins ---
    // mc[7:0]:  uio_out[7:0]   8-bit programmble motor control
    // mc_oe[7:0]: uio_oe[7:0]  8-bit output enable for motor control

    // --- GP I/O Pins ---
    // gpo[6:0]: uo_out[6:0]                      7-bit General Purpose Output
    // gpi[13:0]: {ena, uio_in[7:0], ui_in[4:0]}   5-bit General Purpose Input

    // ----------------------------------
    // SPI Communication Protocol
    // ----------------------------------
    // SPI "mode 0"
    // CPOL = 0, CPHA = 0
    // Data sampled on rising edge and shifted out on the falling edge.
    // Assuming slower than clk freq, ~25 MHz sclk and 50 MHz clk.
    // Data transmitted MSB first.
    // 
    // OP[7:0]: 0x00 = NOP
    //          0x01 = 16-bit read
    //          0x02 = 16-bit write
    //
    // RESULT[7:0]: 0x00 = BUSY
    //              0x01 = WRITE_SUCCESS
    //              0x02 = READ_SUCCESS / DATA_VALID
    //              0xFF = ERROR
    //
    // Write Register, OP = 0x10
    // Shift out 4 bytes, then shift in 1 byte.
    // CMD: <OP[7:0]>, <ADDR[7:0]>, <DATA[15:0]>
    // RSP: <RESULT[7:0]>
    //
    // Read Register, OP = 0x01
    // Shift out 3 bytes, then shift in 3 bytes.
    // CMD: <OP[7:0]>, <ADDR[7:0]>
    // RSP: <RESULT[7:0]>, <DATA[15:0]>

    // ----------------------------------
    // Memory Map
    // ----------------------------------
    // Address  Default R/W   Name
    // 0x00     TBD     R     id
    // 0x01     0x0     R     {ena, mc_in[7:0], gpi[4:0]}
    // 0x02     0x0     R/W   gpo[4:0]
    // 0x03     0x0     R/W   mc_oe[7:0]
    // 0x04     0x0     R/W   step_delay0[15:8]
    // 0x05     0x0     R/W   step_delay1[ 7:0]
    // 0x06     0x0     R/W   {step_dir[0], step_size[2:0]}
    // 0x07     0x0     R/W   {run[0],step[0]}
    // 0x08     0x0     R/W   step_count / write 0 to clear
    // 0x09     0x0     R/W   delay_count / write 0 to clear
    // 0x0A     0x0     R/W   mc_idx
    // 0x0B                   Reserved
    // ...
    // 0x0F                   Reserved
    // 0x10     0x0     R/W   mc[ 0][7:0] step 0
    // ...
    // 0x1F     0x0     R/W   mc[15][7:0] step 15

    rtmc_core core(
        .sck(ui_in[5]),
        .cs_n(ui_in[6]),
        .sdi(ui_in[7]),
        .sdo(uo_out[7]),
        .gpi({ena, uio_in, ui_in[4:0]}),
        .gpo(uo_out[6:0]),
        .mc(uio_out),
        .mc_oe(uio_oe),
        .*
    );

endmodule

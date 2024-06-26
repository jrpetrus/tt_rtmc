/*
 * Copyright (c) 2024 J. R. Petrus
 * SPDX-License-Identifier: Apache-2.0
 */

// Interfaces used for simulation only.
// Lack of fill interface support In Icarus Verilog
// made use of interfaces impossible. Struct support
// was lacking, too.

import rtmc_pkg::*;

interface spi_if();
    logic sclk;
    logic cs;
    logic mosi;
    logic miso;

    modport controller(
        output sclk, cs, mosi,
        input miso
    );

    modport peripheral(
        input sclk, cs, mosi,
        output miso
    );
endinterface

interface gpio_if();
    logic [3:0] gpi;
    logic [3:0] gpo;

    modport controller(
        input gpi,
        output gpo
    );
endinterface

interface motor_if();
    logic [MC_W-1:0] mc;
    logic [MC_W-1:0] mc_oe;

    modport controller(
        output mc, mc_oe
    );
endinterface

interface reg_if #(
    parameter ADDR_W = 8,
    parameter DATA_W = 16
);
    logic [ADDR_W-1:0] addr;
    logic [DATA_W-1:0] wdat;
    logic wr;
    logic rd;
    logic [DATA_W-1:0] rdat;
    logic ack;

    modport initiator(
        output addr,
        output wdat,
        output wr,
        output rd,
        input rdat,
        input ack
    );

    modport responder(
        input addr,
        input wdat,
        input wr,
        input rd,
        output rdat,
        output ack
    );
endinterface

/*
 * Copyright (c) 2024 J. R. Petrus
 * SPDX-License-Identifier: Apache-2.0
 */

 // Bus widths, register offsets, enumerations.

package rtmc_pkg;
    // ID register contents.
    parameter [7:0] VERSION = 'h01;
    parameter [7:0] IDCODE = 'h42;  // "M" in UTF-8

    // Register bus.
    parameter ADDR_W = 8;
    parameter DATA_W = 16;

    // Motor state table.
    parameter MC_W = 8;
    parameter MC_DEPTH = 16;

    parameter TABLE_ADDR_BIT = 4;
    typedef logic[TABLE_ADDR_BIT-1:0] register_address_t;
    typedef logic [$clog2(MC_DEPTH)-1:0] table_address_t;

    // Register offsets.
    typedef enum register_address_t {
        ID_REG = 0,
        GPI_REG = 1,
        GPO_REG = 2,
        MC_OE_REG = 3,
        STEP_CTRL_REG = 4,
        STEP_STAT_REG = 5,
        STEP_DELAY_0_REG = 6,
        STEP_DELAY_1_REG = 7,
        STEP_COUNT_0_REG = 8,
        STEP_COUNT_1_REG = 9,
        DELAY_COUNT_0_REG = 10,
        DELAY_COUNT_1_REG = 11,
        STEP_LIMIT_POS_0_REG = 12,
        STEP_LIMIT_POS_1_REG = 13,
        STEP_LIMIT_NEG_0_REG = 14,
        STEP_LIMIT_NEG_1_REG = 15
    } reg_t;

    // SPI RW protocol.
    typedef enum logic[7:0] {
        O_NOP = 8'h0,
        O_RD = 8'h01,
        O_WR = 8'h02
    } op_t;

    typedef enum logic[7:0] {
        R_BUSY = 8'h00,
        R_ACK = 8'h01,
        R_ACK_DATA = 8'h02
    } result_t;

endpackage
/*
 * Copyright (c) 2024 J. R. Petrus
 * SPDX-License-Identifier: Apache-2.0
 */

 // Bus widths, register offsets, enumerations.

package rtmc_pkg;
    // Register bus.
    parameter ADDR_W = 8;
    parameter DATA_W = 16;

    // Motor state table depth.
    parameter MC_DEPTH = 16;

    // Register offsets.
    typedef enum logic[4:0] {
        ID_REG = 0,
        GPI_REG = 1,
        GPO_REG = 2,
        MC_OE_REG = 3,
        DELAY_0_REG = 4,
        DELAY_1_REG = 5,
        DIR_SIZE_REG = 6,
        RUN_STEP_REG = 7,
        STEP_COUNT_REG = 8,
        DELAY_COUNT_REG = 9,
        MC_INDEX_REG = 10,
        MC_STEP_TABLE = 16
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
        R_ACK_DATA = 8'h02,
        R_ERROR = 8'hFF
    } result_t;

endpackage
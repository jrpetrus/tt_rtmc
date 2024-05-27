/*
 * Copyright (c) 2024 J. R. Petrus
 * SPDX-License-Identifier: Apache-2.0
 */

// Bus widths, register offsets, enumerations.
// Does not work with yosys :(

package rtmc_pkg;
    // Register bus.
    parameter ADDR_W = 8;
    parameter DATA_W = 16;

    // Motor state table.
    parameter MC_W = 8;
endpackage
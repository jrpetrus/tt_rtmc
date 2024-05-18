# SPDX-FileCopyrightText: © 2024 J. R. Petrus
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.triggers import ClockCycles, Timer

from rtmc_testbench import make_tb


@cocotb.test()
async def test_project(dut):
    tb = await make_tb(dut)
    tb.log.info("Test project behavior")

    # Wait for one clock cycle to see the output values
    await ClockCycles(dut.clk, 10)

    # Attempt a write
    addr = 0xC9
    wval = 0xF035
    await tb.write(addr, wval)
    rval = await tb.read(addr)
    assert wval == rval, tb.log.error("Mismatch")

    assert True


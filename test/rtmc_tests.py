# SPDX-FileCopyrightText: © 2024 J. R. Petrus
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.triggers import ClockCycles, Timer
import random

from rtmc_testbench import make_tb, DATA_W


@cocotb.test()
async def test_project(dut):
    tb = await make_tb(dut)
    tb.log.info("Starting test.")

    N_REGS = 32
    wr_regs = list(range(N_REGS))
    rd_regs = list(range(N_REGS))

    # Initialize all registers.
    tb.log.info("Initializing all registers.")
    for addr in wr_regs:
        await tb.write(addr, 0)

    # Randomly write each register in any order.
    tb.log.info("Writing all registers.")
    while wr_regs:
        addr = random.choice(wr_regs)
        wr_regs.remove(addr)
        wdat = random.randrange(1 << DATA_W)
        await tb.write(addr, wdat)

    # Randomly read each register in any order.
    tb.log.info("Reading and checking all registers.")
    while rd_regs:
        addr = random.choice(rd_regs)
        rd_regs.remove(addr)
        rdat = await tb.read(addr)
        assert rdat == tb.regfile[addr], \
            tb.log.error(f"Reg[0x{addr:02X}] mismatch: wrote=0x{tb.regfile[addr]:02X}, read=0x{rdat:02X}!")

    tb.log.info("Test complete.")

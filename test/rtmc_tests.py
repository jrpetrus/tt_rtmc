# SPDX-FileCopyrightText: © 2024 J. R. Petrus
# SPDX-License-Identifier: Apache-2.0

import cocotb
import random

import cocotb.regression

import rtmc_common as rtmc_com
import rtmc_testbench as rtmc_tb


async def test_registers(dut, **kwargs):
    """Test register write and read."""
    tb = await rtmc_tb.make_tb(dut, **kwargs)
    tb.log.info("Starting test.")

    startAddr = rtmc_com.STEP_TABLE_OFFSET
    endAddr = startAddr + rtmc_com.TABLE_DEPTH

    wr_regs = list(range(startAddr, endAddr))
    rd_regs = list(wr_regs)

    # Initialize all registers.
    tb.log.info("Initializing step_table.")
    for addr in wr_regs:
        await tb.write(addr, 0)

    # Randomly write each register in any order.
    tb.log.info("Writing to step_table")
    while wr_regs:
        addr = random.choice(wr_regs)
        wr_regs.remove(addr)
        wdat = random.randrange(1 << (rtmc_com.MC_OUT_WIDTH))
        await tb.write(addr, wdat)

    # Randomly read each register in any order.
    tb.log.info("Reading and checking step_table.")
    while rd_regs:
        addr = random.choice(rd_regs)
        rd_regs.remove(addr)
        rdat = await tb.read(addr)
        assert rdat == tb.regfile[addr], \
            tb.log.error(f"Reg[0x{addr:02X}] mismatch: wrote=0x{tb.regfile[addr]:02X}, read=0x{rdat:02X}!")
        
    # Read and print each register.
    tb.log.info("Read and print all registers.")
    for regName in rtmc_com.REG_MAP.keys():
        regVal = await tb.read(regName)
        tb.log.info(rtmc_com.get_reg_str(regName, regVal))

    # Dump the step table.
    tableStr = "Step Table Contents"
    for i, addr in enumerate(range(startAddr, endAddr)):
        tableVal = await tb.read(addr)
        tableStr += f"\n\t[{i}] = 0b{tableVal:08b}"
    tb.log.info(tableStr)

    tb.log.info("Test complete.")


regs_tf = cocotb.regression.TestFactory(test_function=test_registers)
regs_tf.add_option("spi_mult", [2, 4, 8])
regs_tf.add_option("spi_frame_spacing", [None, 3, 7])
regs_tf.generate_tests()

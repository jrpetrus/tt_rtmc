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
    await tb.finish()


@cocotb.test()
async def test_single_step(dut, **kwargs):
    """Test the single-stepping feature."""
    tb = await rtmc_tb.make_tb(dut, **kwargs)
    tb.log.info("Starting test.")

    tb.log.info("Initializing step_table.")
    step_table = list(range(1, rtmc_com.TABLE_DEPTH + 1))
    await tb.write_step_table(step_table)
    await tb.write_reg("gpio", "mc_oe", (1 << rtmc_com.MC_OUT_WIDTH) - 1)

    # The table_last index MUST be a multiple of step_size.
    step_sizes = [1, 2, 4, -1, -2, -4]
    table_lasts = [rtmc_com.TABLE_DEPTH - abs(s) for s in step_sizes]

    # Track index and step count.
    step_idx = 0
    step_count = 0

    # Iterate through some combinations.
    for step_size, table_last in zip(step_sizes, table_lasts):
        tb.log.info(f"Checking {step_size=}, {table_last=}.")
        await tb.write_reg("step_ctrl", "table_last", table_last)
        await tb.write_reg("step_ctrl", "step_size", step_size)

        n_steps = 20 if step_size > 0 else 30
        for _ in range(n_steps):
            await tb.write_reg("step_ctrl", "step", 1)
            step_count += step_size
            step_idx = rtmc_com.get_next_step_idx(step_idx, step_size, table_last)            
            exp_mc = step_table[step_idx]
            await tb.step(4)
            got_mc = tb.get_mc_out()
            if (exp_mc != got_mc):
                got_idx = await tb.read_reg("step_stat", "table_idx")
                tb.log.error(f"MC mismatch: expected MC[{step_idx}]={exp_mc:02X}, actual MC[{got_idx}]={got_mc:02X}")

        # Check the final step count.
        got_step_count = await tb.read_counter("step_count", signed=True)
        if step_count != got_step_count:
            tb.log.error(f"step_count mismatch: expected={step_count}, actual={got_step_count}!")

    tb.log.info("Test complete.")
    await tb.finish()


@cocotb.test()
async def test_delay_stepping(dut, **kwargs):
    """Test the auto-stepping with delay feature."""
    tb = await rtmc_tb.make_tb(dut, **kwargs)
    tb.log.info("Starting test.")

    # My stepper motor is a 28BYJ-48.
    # It has 8 possible coil positions.
    coil_positions = 8
    MOTOR_SEQ_28BYJ_48 = [
        0b1001,
        0b1000,
        0b1100,
        0b0100,
        0b0110,
        0b0010,
        0b0011,
        0b0001,
    ]
    # Build the step table such that the motors rotate in opposite directions.
    step_table = [(MOTOR_SEQ_28BYJ_48[coil_positions-i-1] << 4) | s for i, s in enumerate(MOTOR_SEQ_28BYJ_48)]

    step_table_str = "\n".join([f"{s:08b}" for s in step_table])
    tb.log.info(f"Initializing step_table for 2x 28BYJ-48 stepper motors:\n{step_table_str}")
    await tb.write_step_table(step_table)
    await tb.write_reg("gpio", "mc_oe", (1 << rtmc_com.MC_OUT_WIDTH) - 1)

    # Most motors only need 8 states.
    # Delays for real stepper motors will be in the 1000s of clock cycles.
    # Ain't nobody got time for that.
    step_sizes = [-2, 1]
    table_lasts = [coil_positions - abs(s) for s in step_sizes]
    step_delays = [15, 31]
    duration = 200

    # Run some combinations.
    for step_size, table_last, step_delay in zip(step_sizes, table_lasts, step_delays):
        tb.log.info(f"Checking {step_size=}, {table_last=}, {step_delay=}.")
        await tb.write_reg("step_ctrl", "table_last", table_last)
        await tb.write_reg("step_ctrl", "step_size", step_size)
        await tb.write_counter("step_delay", step_delay)
        await tb.write_reg("step_ctrl", "run", 1)
        await tb.step(duration)
        await tb.write_reg("step_ctrl", "run", 0)

        # Print the current state.
        got_step_count = await tb.read_counter("step_count", signed=True)
        got_delay_count = await tb.read_counter("delay_count")
        got_idx = await tb.read_reg("step_stat", "table_idx")
        got_state = await tb.read_reg("step_stat", "state")
        tb.log.info(f"table_idx={got_idx}, step_count={got_step_count}, delay_count={got_delay_count}")

        # It would be more work than I'd like to model the state machine and continually check it.
        # Instead, I will check the status for sane values.
        if got_state != 0:
            tb.log.error(f"state={got_state} is not 0!")

        if got_idx > table_last:
            tb.log.error(f"table_idx={got_idx} exceeds {table_last=}!")

        min_steps = (duration // (step_delay + 1)) * step_size
        if step_size > 0:
            if got_step_count < min_steps:
                tb.log.error(f"{min_steps=} but step_count={got_step_count}!")
        else:
            if got_step_count > min_steps:
                tb.log.error(f"{min_steps=} but step_count={got_step_count}!")

        if got_delay_count > step_delay:
            tb.log.error(f"{step_delay=} but delay_count={got_delay_count}!")

        # Clear all counters.
        for cnt_name in ("step_count", "delay_count", "step_delay"):
            await tb.write_counter(cnt_name, 0)

    tb.log.info("Test complete.")
    await tb.finish()


@cocotb.test()
async def test_gpio(dut, **kwargs):
    """Test the GPIO."""
    tb = await rtmc_tb.make_tb(dut, **kwargs)
    tb.log.info("Starting test.")

    gpio_values = range(0, 1 << len(tb.dut.gpio.gpi))

    # Test gpi.
    for val in gpio_values:
        tb.set_gpi(val)
        gpi = await tb.read_reg("gpio", "gpi")
        if gpi != val:
            tb.log.error(f"GPI Mismatch: expected={val:04b}, actual={gpi:04b}")

    # Test gpo.
    for val in gpio_values:
        await tb.write_reg("gpio", "gpo", val)
        gpo = tb.get_gpo()
        if gpo != val:
            tb.log.error(f"GPO Mismatch: expected={val:04b}, actual={gpo:04b}")

    tb.log.info("Test complete.")
    await tb.finish()


regs_tf = cocotb.regression.TestFactory(test_function=test_registers)
regs_tf.add_option("spi_mult", [4, 8])
regs_tf.add_option("spi_frame_spacing", [None, 3, 7])
regs_tf.generate_tests()

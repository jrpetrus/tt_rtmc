# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer


def set_packed_bit(dut_word, bit_idx, bit_val):
    val = int(dut_word.value)
    val |= (bit_val & 0x1) << bit_idx
    dut_word.value = val


def get_packed_bit(dut_word, idx):
    return (int(dut_word.value) >> idx) & 0x1


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    dut.spi.sck.value = 0
    dut.spi.cs_n.value = 1
    dut.spi.sdi.value = 0
    dut.gpio.gpi.value = 0
    await Timer(10, "ns")

    # Set the clock period to 20 ns (50 MHz)
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    set_packed_bit(dut.gpio.gpi, 13, 1)
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # # Set the input values you want to test
    # dut.ui_in.value = 20
    # dut.uio_in.value = 30

    # Wait for one clock cycle to see the output values
    await ClockCycles(dut.clk, 10)

    assert True


# SPDX-FileCopyrightText: © 2024 J. R. Petrus
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer
from cocotbext import spi

import enum
import logging

# Constants
ADDR_W = 8
DATA_W = 16
ADDR_MASK = (1 << ADDR_W) - 1
DATA_MASK = (1 << DATA_W) - 1

SYS_CLK_PERIOD_NS = 20
SPI_CLK_PERIOD_NS = SYS_CLK_PERIOD_NS * 2
SPI_CLK_FREQ_HZ =  1e9 / SPI_CLK_PERIOD_NS
ENA_BIT = 13


class Op(enum.IntEnum):
    NOP = 0
    RD = 1
    WR = 2


class Result(enum.IntEnum):
    BUSY = 0x0
    ACK = 0x1
    ACK_DATA = 0x2
    ERROR = 0xFF


class Testbench:
    def __init__(self, dut, name="tb"):
        self.dut = dut
        self.log = logging.getLogger(f"cocotb.{name}")

        # SPI config.
        spi_config = spi.SpiConfig(
            word_width = 8,
            sclk_freq  = SPI_CLK_FREQ_HZ,
            cpol       = False,
            cpha       = False,
            msb_first  = True,
            data_output_idle = 1,
            frame_spacing_ns = SPI_CLK_PERIOD_NS,
            ignore_rx_value = None,
            cs_active_low = True
        )

        # SPI bus.
        spi_bus = spi.SpiBus.from_entity(self.dut.spi)

        # SPI driver.
        self.spi = spi.SpiMaster(spi_bus, spi_config)

        # Create the clock.
        clock = Clock(dut.clk, SYS_CLK_PERIOD_NS, units="ns")
        cocotb.start_soon(clock.start())

        # Hold current state of every register written by test case.
        self.regfile = {}

    async def reset(self):
        # Initialize inputs.
        self.dut.gpio.gpi.value = 0
        await Timer(SYS_CLK_PERIOD_NS // 2, "ns")

        # Reset
        Testbench.set_bit(self.dut.gpio.gpi, ENA_BIT, 1)
        self.dut.rst_n.value = 0
        await ClockCycles(self.dut.clk, 10)
        self.dut.rst_n.value = 1

    @staticmethod
    def set_bit(signal: cocotb.handle.ModifiableObject, bit_idx: int, bit_val: int) -> None:
        val = int(signal.value)
        val |= (bit_val & 0x1) << bit_idx
        signal.value = val

    @staticmethod
    def get_bit(signal: cocotb.handle.ModifiableObject, idx: int) -> int:
        return (int(signal.value) >> idx) & 0x1

    async def write(self, addr: int, val: int, timeout=64) -> None:
        """SPI write."""
        # Send the write command.
        txDat = int(Op.WR).to_bytes(1)
        txDat += (addr & ADDR_MASK).to_bytes(ADDR_W // 8, byteorder="big")
        txDat += (val & DATA_MASK).to_bytes(DATA_W // 8, byteorder="big")
        txDat += int(Op.NOP).to_bytes(1)
        await self.spi.write(txDat, burst=True)
        rxDat = await self.spi.read(len(txDat))

        # Wait for the response.
        result = Result(rxDat[-1])
        while result == Result.BUSY and timeout:
            await self.spi.write(int(Op.NOP).to_bytes(1), burst=True)
            rxDat = await self.spi.read(1)
            result = Result(int.from_bytes(rxDat))
            timeout -= 1

        if not timeout and result == Result.BUSY:
            raise RuntimeError("SPI write timeout!")

        if result != Result.ACK:
            raise RuntimeError(f"SPI write bad result: {result}!")
        
        # Uopdate register file.
        self.regfile[addr] = val

        await self.spi.wait()

    async def read(self, addr: int, timeout=64) -> int:
        """SPI read."""
        # Send the write command.
        txDat = int(Op.RD).to_bytes(1)
        txDat += (addr & ADDR_MASK).to_bytes(ADDR_W // 8, byteorder="big")
        await self.spi.write(txDat, burst=True)
        rxDat = await self.spi.read(len(txDat))

        # Wait for the response.
        result = Result(rxDat[-1])
        #result = Result.BUSY
        while result == Result.BUSY and timeout:
            await self.spi.write(int(Op.NOP).to_bytes(1), burst=True)
            rxDat = await self.spi.read(1)
            result = Result(int.from_bytes(rxDat))
            timeout -= 1

        if not timeout and result == Result.BUSY:
            raise RuntimeError("SPI read timeout!")

        if result != Result.ACK_DATA:
            raise RuntimeError(f"SPI read bad result: {result}!")

        # Get the resulting data.
        txDat = bytes([int(Op.NOP)] * (DATA_W // 8))
        await self.spi.write(txDat, burst=True)
        rxDat = await self.spi.read(len(txDat))
        await self.spi.wait()
        return int.from_bytes(rxDat, byteorder="big")

async def make_tb(dut):
    tb = Testbench(dut)
    await tb.reset()
    return tb

# SPDX-FileCopyrightText: © 2024 J. R. Petrus
# SPDX-License-Identifier: Apache-2.0

import cocotb
import logging

from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer
from cocotbext import spi

import rtmc_common as rtmc_com

class Testbench:
    def __init__(self, dut, name="tb"):
        self.dut = dut
        self.log = logging.getLogger(f"cocotb.{name}")

        # SPI config.
        spi_config = spi.SpiConfig(
            word_width = 8,
            sclk_freq  = rtmc_com.SPI_CLK_FREQ_HZ,
            cpol       = False,
            cpha       = False,
            msb_first  = True,
            data_output_idle = 1,
            frame_spacing_ns = rtmc_com.SPI_CLK_PERIOD_NS,
            ignore_rx_value = None,
            cs_active_low = True
        )

        # SPI bus.
        spi_bus = spi.SpiBus.from_entity(self.dut.spi)

        # SPI driver.
        self.spi = spi.SpiMaster(spi_bus, spi_config)

        # Create the clock.
        clock = Clock(dut.clk, rtmc_com.SYS_CLK_PERIOD_NS, units="ns")
        cocotb.start_soon(clock.start())

        # Hold current state of every register written by test case.
        self.regfile = {}

    async def reset(self):
        # Initialize inputs.
        self.dut.gpio.gpi.value = 0
        await Timer(rtmc_com.SYS_CLK_PERIOD_NS // 2, "ns")
        Testbench.set_packed_bit(self.dut.gpio.gpi, rtmc_com.ENA_BIT, 1)

        # Reset.
        self.dut.rst_n.value = 0
        await ClockCycles(self.dut.clk, 10)
        self.dut.rst_n.value = 1
        await ClockCycles(self.dut.clk, 10)

    @staticmethod
    def set_packed_bit(signal: cocotb.handle.ModifiableObject, bit_idx: int, bit_val: int) -> None:
        val = int(signal.value)
        val |= (bit_val & 0x1) << bit_idx
        signal.value = val

    @staticmethod
    def get_packed_bit(signal: cocotb.handle.ModifiableObject, idx: int) -> int:
        return (int(signal.value) >> idx) & 0x1

    async def write(self, addr: int | str, val: int, timeout=64) -> None:
        """SPI write."""
        if isinstance(addr, str):
            addr = rtmc_com.REG_MAP[addr]

        # Send the write command.
        txDat = int(rtmc_com.Op.WR).to_bytes(1)
        txDat += (addr & rtmc_com.ADDR_MASK).to_bytes(rtmc_com.ADDR_W // 8, byteorder="big")
        txDat += (val & rtmc_com.DATA_MASK).to_bytes(rtmc_com.DATA_W // 8, byteorder="big")
        txDat += int(rtmc_com.Op.NOP).to_bytes(1)
        await self.spi.write(txDat, burst=True)
        rxDat = await self.spi.read(len(txDat))

        # Wait for the response.
        result = rtmc_com.Result(rxDat[-1])
        while result == rtmc_com.Result.BUSY and timeout:
            await self.spi.write(int(rtmc_com.Op.NOP).to_bytes(1), burst=True)
            rxDat = await self.spi.read(1)
            result = rtmc_com.Result(int.from_bytes(rxDat))
            timeout -= 1

        if not timeout and result == rtmc_com.Result.BUSY:
            raise RuntimeError("SPI write timeout!")

        if result != rtmc_com.Result.ACK:
            raise RuntimeError(f"SPI write bad result: {result}!")
        
        # Uopdate register file.
        self.regfile[addr] = val

        await self.spi.wait()

    async def read(self, addr: int | str, timeout=64) -> int:
        """SPI read."""
        if isinstance(addr, str):
            addr = rtmc_com.REG_MAP[addr]

        # Send the write command.
        txDat = int(rtmc_com.Op.RD).to_bytes(1)
        txDat += (addr & rtmc_com.ADDR_MASK).to_bytes(rtmc_com.ADDR_W // 8, byteorder="big")
        await self.spi.write(txDat, burst=True)
        rxDat = await self.spi.read(len(txDat))

        # Wait for the response.
        result = rtmc_com.Result(rxDat[-1])
        #result = Result.BUSY
        while result == rtmc_com.Result.BUSY and timeout:
            await self.spi.write(int(rtmc_com.Op.NOP).to_bytes(1), burst=True)
            rxDat = await self.spi.read(1)
            result = rtmc_com.Result(int.from_bytes(rxDat))
            timeout -= 1

        if not timeout and result == rtmc_com.Result.BUSY:
            raise RuntimeError("SPI read timeout!")

        if result != rtmc_com.Result.ACK_DATA:
            raise RuntimeError(f"SPI read bad result: {result}!")

        # Get the resulting data.
        txDat = bytes([int(rtmc_com.Op.NOP)] * (rtmc_com.DATA_W // 8))
        await self.spi.write(txDat, burst=True)
        rxDat = await self.spi.read(len(txDat))
        await self.spi.wait()
        return int.from_bytes(rxDat, byteorder="big")
    
    async def write_reg(
        self,
        name: str,
        field: str | None,
        val: int,
    ) -> None:
        """Read-modify-write a register field."""
        bit_offset, _, bit_mask = rtmc_com.get_field_info(name, field)
        reg_val = await self.read(name)
        reg_val &= rtmc_com.DATA_MASK ^ (bit_mask << bit_offset)
        reg_val |= (val & bit_mask) << bit_offset
        await self.write(name, reg_val)

    async def read_reg(
        self,
        name: str,
        field: str | None,
    ) -> None:
        """Read a register field."""
        bit_offset, _, bit_mask = rtmc_com.get_field_info(name, field)
        val = await self.read(name)
        return (val >> bit_offset) & bit_mask
    

async def make_tb(dut):
    tb = Testbench(dut)
    await tb.reset()
    return tb

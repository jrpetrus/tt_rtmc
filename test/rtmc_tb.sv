`default_nettype none
`timescale 1ns / 1ps

import rtmc_pkg::*;

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/

module rtmc_tb();

  // Dump the signals to a VCD file. You can view it with gtkwave.
  initial begin
    $dumpfile("rtmc_tb.vcd");
    $dumpvars(0, rtmc_tb);
  end

  // Wire up the inputs and outputs.
  logic clk;
  logic rst_n;
  spi_if spi();
  gpio_if gpio();
  motor_if motor();

  logic [2:0] uo_dont_care;
  logic ena;

  /*
  Inputs
  ui[0]: "General Purpose Input gpi[0]"
  ui[1]: "General Purpose Input gpi[1]"
  ui[2]: "General Purpose Input gpi[2]"
  ui[3]: "General Purpose Input gpi[3]"
  ui[4]: "SPI0.cs"
  ui[5]: "SPI0.sck"
  ui[6]: "SPI0.tx"
  ui[7]: "Connected to uo[6]"

  Outputs
  uo[0]: "General Purpose Output gpo[0]"
  uo[1]: "General Purpose Output gpo[1]"
  uo[2]: "General Purpose Output gpo[2]"
  uo[3]: "General Purpose Output gpo[3]"
  uo[4]: "Connected to ^uio_in"
  uo[5]: "Connected to ui[7]"
  uo[6]: "Connected to ena"
  uo[7]: "SPI0.rx"

  Bidirectional pins
  uio[0]: "Motor Control mc[0]"
  uio[1]: "Motor Control mc[1]"
  uio[2]: "Motor Control mc[2]"
  uio[3]: "Motor Control mc[3]"
  uio[4]: "Motor Control mc[4]"
  uio[5]: "Motor Control mc[5]"
  uio[6]: "Motor Control mc[6]"
  uio[7]: "Motor Control mc[7]"
  */

  tt_um_rtmc_top_jrpetrus dut(
      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(1'b1),
      .VGND(1'b0),
`endif
      .ui_in({1'b0, spi.mosi, spi.sclk, spi.cs, gpio.gpi}),
      .uo_out({spi.miso, uo_dont_care, gpio.gpo}),
      .uio_in(8'd0),
      .uio_out(motor.mc),
      .uio_oe(motor.mc_oe),
      .ena(ena),
      .clk(clk),
      .rst_n(rst_n)
  );

endmodule

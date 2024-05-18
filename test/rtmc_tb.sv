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

  tt_um_rtmc_top_jrpetrus dut(
      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(1'b1),
      .VGND(1'b0),
`endif
      .ui_in({spi.mosi, spi.cs, spi.sclk, gpio.gpi[4:0]}),
      .uo_out({spi.miso, gpio.gpo}),
      .uio_in(gpio.gpi[12:5]),
      .uio_out(motor.mc),
      .uio_oe(motor.mc_oe),
      .ena(gpio.gpi[13]),
      .clk(clk),
      .rst_n(rst_n)
  );

endmodule

# RTMC Testbench

## How to run

To run the RTL simulation in Icarus (default):

```sh
make -B
```

To run the RTL simulation in Verilator:

```sh
make -B SIM=verilator
```

To run gatelevel simulation, first harden your project and copy `../runs/wokwi/results/final/verilog/gl/tt_um_rtmc_top_jrpetrus.v` to `gate_level_netlist.v`.

Then run:

```sh
make -B GATES=yes
```

## How to view the VCD file

```sh
gtkwave rtmc_tb.sv
```

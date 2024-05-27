![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Tiny Tapeout: Real Time Motor Controller (RTMC)

A SPI-programmable state machine to control a stepper motor with precise duration between steps.

[Read the documentation for project](docs/info.md)

## Why!?

Back in 2020, I got into astrophotography and quickly learned that long exposure photos of the night sky create star trails
that "smear" across your sensor due to the rotation of the Earth. This can be compensated with a simple machine sometimes known
as a Barn Door Star Tracker.

I followed this excellent guide by Nick Touran to build my own. Not having an Arduino handy, I instead built mine with a Raspberry PI 1.
https://partofthething.com/thoughts/making-a-cheap-and-simple-barn-door-star-tracker-with-software-tangent-correction-for-astrophotography/

What irked me at the time was that the Raspberry Pi runs Linux, and Linux is not a real-time operating system. I got pretty good results
with some questionable calibration but always questioned the accuracy of the sleep cycles between steps. Certainly, a microcontroller
running bare-metal C would do a fine job of this. However, I'm a chip designer, I like precision, and this can fit in a 1x2 TinyTapeout tile.

## Future Work

I plan to build a full star tracker using this design and the TinyTapeout demo board. For now, you'll have to settle for some photos and a
video of my old one.

![Star Tracker at night](https://github.com/jrpetrus/tt_rtmc/blob/main/docs/star_tracker_1.jpeg?raw=true)
![Star Tracker at night](https://github.com/jrpetrus/tt_rtmc/blob/main/docs/star_tracker_1.jpeg?raw=true)

[The landscape moves but the stars do not!](docs/star_tracker_demo.mp4)
# SNES for MiSTer by [srg320](https://github.com/srg320)

Ported to ULX3S using Yosys+ghdl+nextpnr+trellis

It includes support for Bluetooth gamepads using ESP32 software from [this repo](https://github.com/dan-rodrigues/ulx3s-bluetooth-gamepad).

It's assumed that the ESP32 software from the above repo has been flashed before programming with `snes.bit` in this repo. The blue LED on the bottom of the board (D22) will blink until a gamepad is connected, at which point it will remain on.

## Requirements
 - ULX3S 85k
 - Latest Yosys, ghdl, ghdl-yosys-plugin, nextpnr and Trellis
 - SNES ROM(s)

## Building for ULX3S

Flash some SNES ROMs using fujprog. ROMs start at address 0x200000 and are spaced by 0x100000.
(the start offset in 0x100000 units is selected by DIP switches [3:1]). ROM type and size is
auto-detected, plain 'smc' format ROMs should be used.

Currently only ROMs without DSP or SA1 work correctly.

Run the following commands to build and program:

    cd ulx3s/scripts
    export PLUGIN_DIR=/path/to/ghdl-yosys-plugin
    bash build.sh
    fujprog-v42-linux-x64 snes.bit

Set DIP switch 0 to select PAL or NTSC, and use DIP switches 3..1 to select the ROM starting
offset in flash. Connect an HDMI monitor or TV capable of 640x480 to the ULX3S.

The button mapping is as follows:

 - Direction buttons: SNES direction PAD
 - Fire 1: B
 - Fire 2: Y
 - Power: START
 - Fire 1 + Fire 2 + Power: RESET

Other SNES buttons are not mapped and would require an external controller (see Known Issues.)

## Simulating using CXXRTL

A 512kB, LoROM, no enhancement chip ROM is currently required (Super Mario World is recommended).

Run:

    cd ulx3s/scripts
    mkdir snes_frames
    python ../util/conv_rom_to_hex.py my_snes_rom.smc > rom.init
    bash simulate.sh

To convert the CSV format frame to an image, run:

    python ../util/convert_frame.py snes_frames/snes_frame87.csv frame_out.png

Note that CXXRTL simulation requires very recent Yosys and G++.

## Known Issues

 - Audio is output to the 3.5mm connector, but is currently distorted and broken
 - DSP enhancement chip is included in the build, but doesn't seem to function correctly
 - Currently a framebuffer is used to match the SNES video mode with HDMI. This increases
   BRAM usage and latency. If a suitable mode could be found and adapter module written,
   a linebuffer approach would be better.
 - Hires video mode is not supported.
 - External controller support is needed to enable all buttons of the SNES to be used.
 - Loading ROMs from microSD or over WiFI via ESP32 would be easier than programming
   them to SPI flash.


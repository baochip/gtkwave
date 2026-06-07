# Baochip GTKWave Fork

This is a fork of the GTKWave simulator. The main feature of this fork is it implements the "code zoom" feature. This allows the simulation to drive a terminal program to display the line of code currently being viewed in the simulation waveform.

The version of GTKwave with the patch is [`gtkwave3-gtk3`](/gtkwave3-gtk3).

## Build Notes

On Ubuntu, the following dependencies are required:

`apt-get install libtcl8.6 tcl8.6-dev libtk8.6 tk8.6 tk8.6-dev gperf zlib1g-dev libbz2-dev liblzma-dev libgtk2.0-dev`

You can then follow the instructions [here](./gtkwave3-gtk3/README.md).

## Pre-Built Binaries

Linux and Windows users can download pre-built, stand-alone binaries under [releases](https://github.com/baochip/gtkwave/releases).

## About the Code Zoom Protocol

The code zoom protocol streams the current "mouse hover" contents over a UDP socket (default 6502) to localhost. This allows any program running on the same host listening to the port to pick up the mouse hover contents and react to it.

Because the Baochip RTL is fixed, we can home in on `dbg_pc` as the source of the program counter, and then highlight the line of assembly code that corresponds to the program counter.
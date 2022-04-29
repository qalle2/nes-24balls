# 24 Balls
A demo for the [NES](https://en.wikipedia.org/wiki/Nintendo_Entertainment_System). Shows 24 bouncing balls. No sound. Tested on Mednafen and FCEUX.

![screenshot](snap.png)

Table of contents:
* [List of files](#list-of-files)
* [How to assemble](#how-to-assemble)

## List of files
* `24balls.asm`: source code (assembles with [ASM6](https://github.com/qalle2/asm6))
* `24balls.nes.gz`: assembled program (iNES format, gzip compressed)
* `assemble.sh`: a Linux script that assembles the program (warning: deletes files)
* `chr.bin.gz`: CHR ROM data (gzip compressed)
* `chr.png`: graphics data as an image
* `snap.png`: screenshot

## How to assemble
* Get the CHR ROM data:
  * Either uncompress it from `chr.bin.gz`&hellip;
  * &hellip;or encode it yourself: `python3 nes_chr_encode.py chr.png chr.bin` (see my [my NES utilities](https://github.com/qalle2/nes-util) repository).
* Assemble: `asm6 24balls.asm 24balls.nes`

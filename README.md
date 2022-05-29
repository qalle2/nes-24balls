# 24 Balls
A demo for the [NES](https://en.wikipedia.org/wiki/Nintendo_Entertainment_System). Shows 24 bouncing balls. Tested on Mednafen and FCEUX.

![screenshot](snap.png)

Table of contents:
* [List of files](#list-of-files)
* [Technical info](#technical-info)

## List of files
* `24balls.asm`: source code (assembles with [ASM6](https://github.com/qalle2/asm6))
* `24balls.nes.gz`: assembled program (iNES format, gzip compressed)
* `assemble.sh`: a Linux script that assembles the program (warning: deletes files)
* `snap.png`: screenshot

## Technical info
* mapper: NROM
* PRG ROM: 16 KiB (only 1 KiB is actually used)
* CHR ROM: none (uses CHR RAM)
* name table mirroring: does not matter
* compatibility: NTSC and PAL

# 24 Balls
A demo for the [Nintendo Entertainment System](http://en.wikipedia.org/wiki/Nintendo_Entertainment_System) (NES). Assembles with ASM6. Shows 24 bouncing balls. No sound. Only tested on Mednafen. The assembled program (`.nes`) is in `24balls.nes.gz`.

## How to assemble
* Get the CHR ROM data:
  * Either uncompress it from `chr.bin.gz`&hellip;
  * &hellip;or encode it yourself: `python3 nes_chr_encode.py chr.png chr.bin` (see my [my NES utilities](https://github.com/qalle2/nes-util) repository).
* Assemble:
  * Run `asm6 24balls.asm 24balls.nes`

Note: the Linux script `assemble.sh` is for my personal use. Do not run it before reading it.

## Screenshot
![24 Balls](snap.png)

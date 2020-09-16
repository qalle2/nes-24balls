# nes-24balls
24 Balls, a demo for the [Nintendo Entertainment System](http://en.wikipedia.org/wiki/Nintendo_Entertainment_System) (NES). Shows 24 bouncing balls. Only tested on [FCEUX](http://www.fceux.com). The assembled program (`.nes`) is in `binaries.zip`.

## How to assemble
* Install **asm6f**:
  * [GitHub page](https://github.com/freem/asm6f)
  * [64-bit Windows binary](http://qallee.net/misc/asm6f-win64.zip) (compiled by me)
* Get the CHR ROM data:
  * Either uncompress it from `binaries.zip`&hellip;
  * &hellip;or encode it yourself: `python3 nes_chr_encode.py chr.png chr.bin` (see my [my NES utilities](https://github.com/qalle2/nes-util) repository).
* To assemble:
  * Get `nes.asm` from [my NES utilities](https://github.com/qalle2/nes-util).
  * Go to the `src` subdirectory and run `asm6f 24balls.asm ../24balls.nes`

Note: the Linux script `assemble` is for my personal use. Do not run it before reading it.

## Screenshot
![24 Balls](snap.png)


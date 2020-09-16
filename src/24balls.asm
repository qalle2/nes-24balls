; 24 Balls (NES, ASM6f)

    ; value to fill unused areas with
    fillvalue $ff

    include "../../nes-util/nes.asm"  ; see readme
    include "constants.asm"

; --- iNES header ---------------------------------------------------------------------------------

    inesprg 1  ; PRG ROM: 16 KiB
    ineschr 1  ; CHR ROM:  8 KiB
    inesmir 0  ; name table mirroring: horizontal
    inesmap 0  ; mapper: NROM

; --- PRG ROM -------------------------------------------------------------------------------------

    org $c000               ; last 16 KiB of CPU memory space
    include "init.asm"
    include "mainloop.asm"
    align $100              ; for speed
    include "nmi.asm"
    pad $fffa
    dw nmi, reset, $ffff    ; interrupt vectors

; --- CHR ROM -------------------------------------------------------------------------------------

    pad $10000
    incbin "../chr.bin"
    pad $12000


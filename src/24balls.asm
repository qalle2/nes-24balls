; 24 Balls (NES, ASM6f)

    ; value to fill unused areas with
    fillvalue $ff

    include "constants.asm"
    include "macros.asm"

; --- iNES header ---------------------------------------------------------------------------------

    inesprg 1  ; PRG ROM: 16 KiB
    ineschr 1  ; CHR ROM:  8 KiB
    inesmir 0  ; name table mirroring: horizontal
    inesmap 0  ; mapper: NROM

; --------------------------------------------------------------------------------------------------

    org $c000                       ; last 16 KiB of PRG ROM
    pad $f800                       ; last  2 KiB of PRG ROM
    include "init.asm"
    include "mainloop.asm"
    include "nmi.asm"
    include "common.asm"

; --- Interrupt vectors ---------------------------------------------------------------------------

    pad $fffa
    dw nmi, reset, $ffff

; --- CHR ROM -------------------------------------------------------------------------------------

    pad $10000
    incbin "../chr.bin"
    pad $12000


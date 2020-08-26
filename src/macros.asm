; 24 Balls - macros

macro initialize_nes
    ; Initialize the NES.
    ; Do this at the start of the program.
    ; Afterwards, do a wait_vblank before doing any PPU operations. In between, you have about
    ; 30,000 cycles to do non-PPU-related stuff.
    ; See http://wiki.nesdev.com/w/index.php/Init_code

    sei           ; ignore IRQs
    cld           ; disable decimal mode
    ldx #$40
    stx joypad2   ; disable APU frame IRQ
    ldx #$ff
    txs           ; initialize stack pointer
    inx
    stx ppu_ctrl  ; disable NMI
    stx ppu_mask  ; disable rendering
    stx dmc_freq  ; disable DMC IRQs

    wait_vblank_start
endm

macro wait_vblank_start
    ; wait until start of VBlank
    bit ppu_status
-   bit ppu_status
    bpl -
endm


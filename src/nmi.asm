; 24 Balls - NMI routine

nmi:
    push_registers
    copy_sprite_data sprite_data

    ; copy sprite palette backwards from RAM to VRAM
    set_ppu_address $3f10
    ldx #15
-   lda sprite_palette_ram, x
    sta ppu_data
    dex
    bpl -

    reset_ppu_address_latch
    set_ppu_address $0000
    set_ppu_scroll 0, 0

    set_flag nmi_done
    pull_registers
    rti


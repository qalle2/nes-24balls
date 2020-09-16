; 24 Balls - initialization

reset:
    initialize_nes

    clear_flag nmi_done
    copy_via_a #0, timer

    ; copy first set of sprite palettes from ROM to RAM
    ldx #(16 - 1)
-   lda sprite_palettes, x  ; in mainloop.asm
    sta sprite_palette_ram, x
    dex
    bpl -

    ; fill sprite page with $ff
    ; (it will serve as invisible sprites' Y positions and as negative directions)
    lda #$ff
    ldx #0
-   sta sprite_data, x
    inx
    bne -

    ; sprite tile numbers: all $0a
    ; regs: X = sprite offset
    ;
    lda #$0a
    ldx #0
    ;
-   sta sprite_data + 1, x
    inx
    inx
    inx
    inx
    cpx #(ball_count * 2 * 4)
    bne -

    ; sprite Y positions: 18 + ball_index * 8
    ; regs: X = ball offset
    ;
    ldx #0
    ;
-   txa
    add #18
    sta sprite_data, x
    sta sprite_data + 4, x
    ;
    txa
    add #8
    tax
    ;
    cpx #(ball_count * 8)
    bne -

    ; sprite X positions: left sides from table, add 8 for right sides
    ; regs: Y = ball index, X = ball offset (because 6502 has STA ZP,X), A = position
    ;
    ldy #(ball_count - 1)
    ;
-   tya
    asl
    asl
    asl
    tax
    ;
    lda initial_x, y
    sta sprite_data + 3, x
    add #8
    sta sprite_data + 4 + 3, x
    ;
    dey
    bpl -

    ; sprite attributes:
    ;   - subpalette: ball index modulo 4
    ;   - horizontal flip: odd sprite indexes (right half of each ball)
    ; regs: X = sprite offset (because 6502 has STA ZP,X), Y = source offset, A = data
    ;
    ldx #0
--  ldy #0
    ;
    ; copy attributes of 8 sprites
-   lda initial_attributes, y
    sta sprite_data + 2, x
    inx
    inx
    inx
    inx
    iny
    cpy #8
    bne -
    ;
    cpx #(ball_count * 2 * 4)
    bne --

    ; clear some addresses of ball directions (to make them start in different directions)
    ; regs: X = ball direction offset (because 6502 has STA ZP,X)
    ;
    lda #$00
    ldy #(ball_count - 1)
    ;
-   ldx directions_to_clear, y
    sta sprite_data, x
    dey
    bpl -

    wait_for_vblank_start

    ; copy sprite palette backwards from RAM to VRAM
    set_ppu_address $3f10
    ldx #(16 - 1)
-   lda sprite_palette_ram, x
    sta ppu_data
    dex
    bpl -

    copy_sprite_data sprite_data

    ; set background palette
    set_ppu_address $3f00
    ldx #(4 - 1)
-   lda background_palette, x
    sta ppu_data
    dex
    bpl -

    ; write name table 0
    ;
    set_ppu_address $2000
    ;
    ; 1 line (tile $01)
    lda #$01
    ldx #32
    jsr fill_vram
    ;
    ; 1 line (tiles: $02, 30 * $03, $04)
    lda #$02
    sta ppu_data
    lda #$03
    ldx #30
    jsr fill_vram
    lda #$04
    sta ppu_data
    ;
    ; 26 lines (tiles on each line: $08, 30 * $00, $09)
    ldy #26
-   lda #$08
    sta ppu_data
    lda #$00
    ldx #30
    jsr fill_vram
    lda #$09
    sta ppu_data
    dey
    bne -
    ;
    ; 1 line (tiles: $05, 30 * $06, $07)
    lda #$05
    sta ppu_data
    lda #$06
    ldx #30
    jsr fill_vram
    lda #$07
    sta ppu_data
    ;
    ; 1 line (tile $01)
    lda #$01
    ldx #32
    jsr fill_vram

    ; clear attribute table 0
    lda #$00
    ldx #64
    jsr fill_vram

    reset_ppu_address_latch
    set_ppu_address $0000
    set_ppu_scroll 0, 0

    wait_for_vblank_start

    ; enable NMI, use 8*16-pixel sprites
    copy_via_a #%10100000, ppu_ctrl

    ; show sprites and background
    copy_via_a #%00011110, ppu_mask

    jmp main_loop

; -------------------------------------------------------------------------------------------------

fill_vram:
    ; Print A X times.

-   sta ppu_data
    dex
    bne -
    rts

; -------------------------------------------------------------------------------------------------

initial_x:
    ; initial X positions for balls
    ; minimum: 8 + 1 = 9
    ; maximum: 256 - 16 - 8 - 1 = 231
    ; Python 3: " ".join(format(n, "02x") for n in random.sample(range(9, 231 + 1), 24))
    hex 48 59 32 96 93 c6 26 70
    hex 31 d5 73 e6 3a 34 8c 52
    hex 1c 3d 61 c5 9e 88 b9 e7

initial_attributes:
    db %00000000, %01000000  ; subpalette 0, left/right half of ball
    db %00000001, %01000001  ; subpalette 1, left/right half of ball
    db %00000010, %01000010  ; subpalette 2, left/right half of ball
    db %00000011, %01000011  ; subpalette 3, left/right half of ball

directions_to_clear:
    hex c5 c9 cd d1 d7 db c1 c7 ce d5 d9 df
    hex e5 e9 ed f1 f7 fb e3 ea ef f3 f6 fd

background_palette:
    ; backwards
    db color_bg3, color_bg2, color_bg1, color_bg0


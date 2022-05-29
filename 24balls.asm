; 24 Balls (NES, ASM6)

; TODO:
; - use LFSR or other PRNG for initial values

; --- Constants -----------------------------------------------------------------------------------

; RAM
h_directions    equ $00    ; horizontal directions of balls (24=$18 bytes; nonzero=left, 0=right)
v_directions    equ $18    ; vertical   directions of balls (24=$18 bytes; nonzero=up,   0=down)
run_main_loop   equ $30    ; main loop allowed to run? (MSB: 0=no, 1=yes)
loop_counter    equ $31    ; loop counter
frame_count     equ $32    ; frame counter
spr_pal_ind     equ $33    ; index to start copying sprite palette from (0/16)
spr_data        equ $0200  ; OAM page ($100 bytes)

; memory-mapped registers; see https://wiki.nesdev.org/w/index.php/PPU_registers
ppu_ctrl        equ $2000
ppu_mask        equ $2001
ppu_status      equ $2002
oam_addr        equ $2003
ppu_scroll      equ $2005
ppu_addr        equ $2006
ppu_data        equ $2007
dmc_freq        equ $4010
oam_dma         equ $4014
snd_chn         equ $4015
joypad2         equ $4017

; background colors
col_bg0         equ $0f  ; black
col_bg1         equ $00  ; dark gray
col_bg2         equ $10  ; gray
col_bg3         equ $30  ; white

; misc
ball_tile       equ $0a  ; ball tile (top left quarter; bottom left must immediately follow)
ball_cnt        equ  24  ; number of balls
blink_rate      equ   3  ; ball blink rate (0=fastest, 7=slowest)

; --- iNES header ---------------------------------------------------------------------------------

                ; see https://wiki.nesdev.org/w/index.php/INES
                base $0000
                db "NES", $1a            ; file id
                db 1, 0                  ; 16 KiB PRG ROM, 0 KiB CHR ROM (uses CHR RAM)
                db %00000000, %00000000  ; NROM mapper, name table mirroring doesn't matter
                pad $0010, $00           ; unused

; --- Initialization ------------------------------------------------------------------------------

                base $c000              ; start of PRG ROM
                pad $fc00, $ff          ; last 1 KiB of CPU address space

reset           ; initialize the NES; see https://wiki.nesdev.org/w/index.php/Init_code
                ;
                sei                     ; ignore IRQs
                cld                     ; disable decimal mode
                ldx #%01000000
                stx joypad2             ; disable APU frame IRQ
                ldx #$ff
                txs                     ; initialize stack pointer
                inx
                stx ppu_ctrl            ; disable NMI
                stx ppu_mask            ; disable rendering
                stx dmc_freq            ; disable DMC IRQs
                stx snd_chn             ; disable sound channels

                jsr wait_vbl_start      ; wait until next VBlank starts

                ldy #$00                ; clear zero page (also sets all directions to right/down)
                lda #$ff                ; and fill sprite page with $ff to hide all sprites
                ldx #0                  ; 6502 has no STX nnnn,y or STY nnnn,x
-               sty $00,x
                sta spr_data,x
                inx
                bne -

                ldx #0                  ; sprite Y positions: 18 + ball_index * 8
-               txa
                clc
                adc #18
                sta spr_data,x
                sta spr_data+4,x
                txa
                clc
                adc #8
                tax
                cpx #(ball_cnt*8)
                bne -

                lda #ball_tile          ; sprite tiles
                ldx #0
-               sta spr_data+1,x
                inx
                inx
                inx
                inx
                cpx #(ball_cnt*8)
                bne -

                ldx #0                  ; sprite attributes: subpalette = ball_index modulo 4,
--              ldy #0                  ; horizontal flip = 1 for odd sprite indexes
-               lda init_spr_attr,y     ; 6502 has STA ZP,X but no STA ZP,Y
                sta spr_data+2,x
                inx
                inx
                inx
                inx
                iny
                cpy #8
                bne -
                cpx #(ball_cnt*8)
                bne --

                ldy #(ball_cnt-1)       ; sprite X positions: from table
-               tya                     ; 6502 has STA ZP,X but no STA ZP,Y
                asl a
                asl a
                asl a
                tax
                lda init_x,y
                sta spr_data+3,x
                clc
                adc #8
                sta spr_data+4+3,x
                dey
                bpl -

                lda #$ff                ; make some balls start moving left/up instead of
                ldy #(ball_cnt-1)       ; right/down
-               ldx init_inv_dirs,y     ; 6502 has STA ZP,X but no STA ZP,Y
                sta h_directions,x
                dey
                bpl -

                jsr wait_vbl_start      ; wait until next VBlank starts

                ldy #$3f                ; set background palette (while in VBlank)
                jsr set_ppu_addr_pg     ; 0 -> A; set PPU address page from Y
                ;
                tax
-               lda bg_palette,x
                sta ppu_data
                inx
                cpx #4
                bne -

                ldy #$00                ; copy pattern table data
                jsr set_ppu_addr_pg     ; 0 -> A; set PPU address page from Y
                tax                     ; X = source index
                ;
-               lda pt_data,x           ; get byte using high nybble
                pha
                lsr a
                lsr a
                lsr a
                lsr a
                tay
                lda pt_data_bytes,y
                sta ppu_data
                ;
                pla                     ; get byte using low nybble
                and #%00001111
                tay
                lda pt_data_bytes,y
                sta ppu_data
                ;
                inx
                cpx #($c*8)
                bne -

                ldy #$20                ; clear name & attribute table 0
                jsr set_ppu_addr_pg     ; 0 -> A; set PPU address page from Y
                ;
                tax
                ldy #4
-               sta ppu_data
                inx
                bne -
                dey
                bne -

                ; extract run-length encoded data to name table 0
                ;
                ldx #$ff                ; source index (preincremented)
                ;
--              inx                     ; PPU address ($00xx = terminator)
                ldy nt_rle_data,x
                beq +
                inx
                lda nt_rle_data,x
                jsr set_ppu_addr        ; Y, A -> address
                ;
                inx                     ; length & direction
                lda nt_rle_data,x       ; LLLLLLLV (LLLLLLL = length, V = vertical)
                lsr a
                tay                     ; length
                lda #0
                rol a
                asl a
                asl a
                sta ppu_ctrl            ; address autoincrement (%000 = 1 byte, %100 = 32 bytes)
                ;
                inx                     ; write tile Y times
                lda nt_rle_data,x
-               sta ppu_data
                dey
                bne -
                ;
                beq --                  ; next RLE block (unconditional)

+               jsr wait_vbl_start      ; wait until next VBlank starts
                jsr set_ppu_regs        ; set ppu_scroll/ppu_ctrl/ppu_mask

                jmp main_loop

wait_vbl_start  bit ppu_status          ; wait until next VBlank starts
-               bit ppu_status
                bpl -
                rts

init_spr_attr   ; initial attributes for balls
                ;
                db %00000000, %01000000  ; subpalette 0, left/right half of ball
                db %00000001, %01000001  ; subpalette 1, left/right half of ball
                db %00000010, %01000010  ; subpalette 2, left/right half of ball
                db %00000011, %01000011  ; subpalette 3, left/right half of ball

init_x          ; initial X positions for balls
                ; minimum: 8 + 1 = 9
                ; maximum: 256 - 16 - 8 - 1 = 231
                ; Python 3: " ".join(format(n, "02x") for n in random.sample(range(9, 231+1), 24))
                ;
                hex 48 59 32 96 93 c6 26 70
                hex 31 d5 73 e6 3a 34 8c 52
                hex 1c 3d 61 c5 9e 88 b9 e7

init_inv_dirs   ; balls that initially move left instead of right (indexes to h_directions)
                db  1,  2,  4,  7,  8, 11
                db 13, 14, 16, 19, 21, 22
                ;
                ; balls that initially move up instead of down (with ball_cnt added, indexes to
                ; v_directions)
                db ball_cnt+ 0, ball_cnt+ 1, ball_cnt+ 4, ball_cnt+ 5, ball_cnt+ 8, ball_cnt+10
                db ball_cnt+13, ball_cnt+15, ball_cnt+18, ball_cnt+19, ball_cnt+22, ball_cnt+23

bg_palette      db col_bg0, col_bg1, col_bg2, col_bg3  ; 1st background subpalette

pt_data         ; pattern table data; each nybble is an index to pt_data_bytes
                ;
                hex 00000000 00000000   ; tile $00 (color 0 only)
                hex dddddddd dddddddd   ; tile $01 (color 3 only)
                hex ddddaabb ddddddcc   ; tile $02 (border - top left corner)
                hex dddd00dd dddddd00   ; tile $03 (border - top edge)
                hex dddd2299 dddddd55   ; tile $04 (border - top right corner)
                hex bbaadddd ccdddddd   ; tile $05 (border - bottom left corner)
                hex dd00dddd 00dddddd   ; tile $06 (border - bottom edge)
                hex 9922dddd 55dddddd   ; tile $07 (border - bottom right corner)
                hex bbbbbbbb cccccccc   ; tile $08 (border - left edge)
                hex 99999999 55555555   ; tile $09 (border - right edge)
                hex 13476899 00123555   ; tile $0a (ball - top left)
                hex 99867431 55532100   ; tile $0b (ball - bottom left)

pt_data_bytes   ; actual pattern table data bytes; see pt_data
                ;
                db %00000000            ; index $0
                db %00000111            ; index $1
                db %00001111            ; index $2
                db %00011111            ; index $3
                db %00111000            ; index $4
                db %00111111            ; index $5
                db %01100011            ; index $6
                db %01110000            ; index $7
                db %11000111            ; index $8
                db %11001111            ; index $9
                db %11110000            ; index $a
                db %11110011            ; index $b
                db %11111100            ; index $c
                db %11111111            ; index $d

macro rle_run _y, _x, _length, _vertical, _tile
                ; RLE run (see nt_rle_data)
                ;
                db $20+_y/8
                db (_y&7)*32+_x
                db _length*2|_vertical
                db _tile
endm

nt_rle_data     ; name table RLE data; 1 run = 4 bytes:
                ; - address high (0 = terminator)
                ; - address low
                ; - LLLLLLLV (LLLLLLL = length, V = vertical)
                ; - tile
                ;
                rle_run  0,  0, 32, 0, $01  ; solid color (outside NTSC area)
                rle_run  1,  0,  1, 0, $02  ; top left corner
                rle_run  1,  1, 30, 0, $03  ; top edge
                rle_run  1, 31,  1, 0, $04  ; top right corner
                rle_run  2,  0, 26, 1, $08  ; left edge
                rle_run  2, 31, 26, 1, $09  ; right edge
                rle_run 28,  0,  1, 0, $05  ; bottom left corner
                rle_run 28,  1, 30, 0, $06  ; bottom edge
                rle_run 28, 31,  1, 0, $07  ; bottom right corner
                rle_run 29,  0, 32, 0, $01  ; solid color (outside NTSC area)
                db 0                        ; terminator

; --- Main loop -----------------------------------------------------------------------------------

main_loop       bit run_main_loop       ; wait until NMI routine has set flag
                bpl main_loop

                lsr run_main_loop       ; clear flag

                ldx #(ball_cnt-1)       ; move balls horizontally
                lda frame_count         ; (all on even frames, all except last 8 on odd frames)
                lsr a
                bcc +
                ldx #(ball_cnt-8-1)
+               stx loop_counter        ; last ball to move -> loop_counter
                ;
-               ldy loop_counter        ; ball index -> Y, sprite data offset -> X
                tya
                asl a
                asl a
                asl a
                tax
                lda h_directions,y      ; 1 byte wasted (6502 has no LDA zp,y)
                beq +
                ;
                dec spr_data+3,x        ; move left; if hit wall, change direction
                dec spr_data+4+3,x
                lda spr_data+3,x
                cmp #8
                bne ++
                ldx #$00
                stx h_directions,y      ; 6502 has STX zp,y but no STA zp,y
                beq ++                  ; unconditional
                ;
+               inc spr_data+3,x        ; move right; if hit wall, change direction
                inc spr_data+4+3,x
                lda spr_data+3,x
                cmp #(256-16-8)
                bne ++
                sta h_directions,y      ; nonzero = left; 1 byte wasted (6502 has no STA zp,y)
                ;
++              dec loop_counter
                bpl -

                lda #(ball_cnt-1)       ; move all balls vertically
                sta loop_counter
                ;
-               ldy loop_counter        ; ball index -> Y, sprite data offset -> X
                tya
                asl a
                asl a
                asl a
                tax
                lda v_directions,y      ; 1 byte wasted (6502 has no LDA zp,y)
                beq +
                ;
                dec spr_data+0,x        ; move up; if hit wall, change direction
                dec spr_data+4+0,x
                lda spr_data+0,x
                cmp #(16-1)
                bne ++
                ldx #$00
                stx v_directions,y      ; 6502 has STX zp,y but no STA zp,y
                beq ++                  ; unconditional
                ;
+               inc spr_data+0,x        ; move down; if hit wall, change direction
                inc spr_data+4+0,x
                lda spr_data+0,x
                cmp #(240-16-16-1)
                bne ++
                sta v_directions,y      ; nonzero = up; 1 byte wasted (6502 has no STA zp,y)
                ;
++              dec loop_counter
                bpl -

                ldx #16                 ; which index to start copying sprite palette from (0/16)
                lda frame_count
                and #(1<<blink_rate)
                bne +
                tax
+               stx spr_pal_ind

                inc frame_count         ; advance timer
                jmp main_loop

spr_pals        db col_bg0, $11, $21, $31  ; first set of sprite palettes
                db col_bg0, $14, $24, $34  ; (blue, red, yellow and green)
                db col_bg0, $17, $27, $37
                db col_bg0, $1a, $2a, $3a
                db col_bg0, $12, $22, $32  ; second set of sprite palettes
                db col_bg0, $15, $25, $35  ; (slightly different shades)
                db col_bg0, $18, $28, $38
                db col_bg0, $1b, $2b, $3b

; --- Interrupt routines --------------------------------------------------------------------------

nmi             pha                     ; push A, X, Y
                txa
                pha
                tya
                pha

                bit ppu_status          ; reset ppu_addr/ppu_scroll latch

                lda #$00                ; do OAM DMA
                sta oam_addr
                lda #>spr_data
                sta oam_dma

                ldy #$3f                ; copy one of two sprite palettes to VRAM
                lda #$10
                jsr set_ppu_addr        ; Y, A -> address
                ;
                ldx spr_pal_ind         ; X = source index
                tay                     ; Y = bytes left
-               lda spr_pals,x
                sta ppu_data
                inx
                dey
                bne -

                jsr set_ppu_regs        ; set ppu_scroll/ppu_ctrl/ppu_mask

                sec                     ; set MSB to let main loop run once
                ror run_main_loop

                pla                     ; pull Y, X, A
                tay
                pla
                tax
                pla

irq             rti                     ; IRQ unused

; --- Subs used in many places --------------------------------------------------------------------

set_ppu_addr_pg lda #$00                ; 0 -> A; set PPU address page from Y
set_ppu_addr    sty ppu_addr            ; set PPU address from Y and A
                sta ppu_addr
                rts

set_ppu_regs    lda #$00                ; reset PPU scroll
                sta ppu_scroll
                sta ppu_scroll
                lda #%10100000          ; enable NMI, use 8*16-pixel sprites
                sta ppu_ctrl
                lda #%00011110          ; show sprites and background
                sta ppu_mask
                rts

; --- Interrupt vectors ---------------------------------------------------------------------------

                pad $fffa, $ff
                dw nmi, reset, irq      ; IRQ unused

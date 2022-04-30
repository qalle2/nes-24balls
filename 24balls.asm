; 24 Balls (NES, ASM6)
; Style:
; - ASCII
; - no tabs
; - lines: 100 characters or less (incl. newline)
; - identifiers: 15 characters or less
; - instructions start at 17th column
; - within a block of instructions, comments start at 2 columns after longest instruction,
;   but not earlier than at 41st column (equ is an exception)

; TODO:
; - the sounds sound really bad (study NES audio more)
; - use LFSR or other PRNG for initial values

; --- Constants -----------------------------------------------------------------------------------

; RAM
spr_data        equ $00    ; sprite data; see "zero page layout" below
spr_pal         equ $0200  ; sprite palette (16 bytes, backwards)
run_main_loop   equ $0210  ; MSB = main loop allowed to run (0=no, 1=yes)
loop_counter    equ $0211  ; loop counter
frame_count     equ $0212

; Zero page layout:
;   $00-$bf: visible sprites:
;       192 bytes = 24 balls * 2 sprites/ball * 4 bytes/sprite
;   $c0-$ff: hidden sprites:
;       Y positions ($c0, $c4, $c8, ...): always $ff
;       other bytes: directions of balls ($ff = up/left, $00 = down/right):
;           horizontal: $c1, $c2, $c3; $c5, $c6, $c7; ...; $dd, $de, $df
;           vertical:   $e1, $e2, $e3; $e5, $e6, $e7; ...; $fd, $fe, $ff

; memory-mapped registers; see https://wiki.nesdev.org/w/index.php/PPU_registers
ppu_ctrl        equ $2000
ppu_mask        equ $2001
ppu_status      equ $2002
oam_addr        equ $2003
ppu_scroll      equ $2005
ppu_addr        equ $2006
ppu_data        equ $2007
sq1_vol         equ $4000
sq1_sweep       equ $4001
sq1_lo          equ $4002
sq1_hi          equ $4003
sq2_vol         equ $4004
sq2_sweep       equ $4005
sq2_lo          equ $4006
sq2_hi          equ $4007
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
ball_count      equ  24  ; number of balls
blink_rate      equ   3  ; ball blink rate (0=fastest, 7=slowest)

; --- iNES header ---------------------------------------------------------------------------------

                ; see https://wiki.nesdev.org/w/index.php/INES
                base $0000
                db "NES", $1a            ; file id
                db 1, 1                  ; 16 KiB PRG ROM, 8 KiB CHR ROM
                db %00000000, %00000000  ; NROM mapper, horizontal name table mirroring
                pad $0010, $00           ; unused

; --- Initialization ------------------------------------------------------------------------------

                base $c000              ; start of PRG ROM
                pad $fc00, $ff          ; last 1 KiB of CPU address space

reset           ; initialize the NES; see https://wiki.nesdev.org/w/index.php/Init_code
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

                jsr wait_vbl_start      ; wait until next VBlank starts

                lda #0                  ; clear variables and set sound registers
                sta run_main_loop       ; see https://www.nesdev.org/wiki/APU_Pulse
                sta frame_count
                sta sq1_sweep
                sta sq2_sweep
                sta sq1_lo
                sta sq2_lo
                sta sq1_hi
                sta sq2_hi
                lda #%00000011          ; enable pulse channels
                sta snd_chn
                lda #%10000010          ; duty cycle 50%, vol/env div period 2?
                sta sq1_vol
                sta sq2_vol

                lda #$ff                ; fill sprite page with $ff (it will serve as invisible
                ldx #0                  ; sprites' Y positions and as negative directions)
-               sta spr_data,x
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
                cpx #(ball_count*8)
                bne -

                lda #ball_tile          ; sprite tiles
                ldx #0
-               sta spr_data+1,x
                inx
                inx
                inx
                inx
                cpx #(ball_count*8)
                bne -

                ldx #0                  ; sprite attributes: subpalette = ball_index modulo 4,
--              ldy #0                  ; horizontal flip = 1 for odd sprite indexes
-               lda init_spr_attr,y     ; note: 6502 has STA ZP,X but no STA ZP,Y
                sta spr_data+2,x
                inx
                inx
                inx
                inx
                iny
                cpy #8
                bne -
                cpx #(ball_count*8)
                bne --

                ldy #(ball_count-1)     ; sprite X positions: from table
-               tya                     ; note: 6502 has STA ZP,X but no STA ZP,Y
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

                lda #$00                ; make some balls start moving right/down instead of
                ldy #(ball_count-1)     ; left/up
-               ldx init_inv_dirs,y     ; note: 6502 has STA ZP,X but no STA ZP,Y
                sta spr_data,x
                dey
                bpl -

                jsr wait_vbl_start      ; wait until next VBlank starts

                ldy #$3f                ; set background palette
                lda #$00
                jsr set_ppu_addr        ; Y, A -> address
                tax
-               lda bg_pal,x
                sta ppu_data
                inx
                cpx #16
                bne -

                ldy #$20                ; clear name table 0 and attribute table 0
                lda #$00
                jsr set_ppu_addr        ; Y, A -> address
                tax
                ldy #4
-               sta ppu_data
                inx
                bne -
                dey
                bne -

                ; extract run-length encoded data to name table 0
                ldx #$ff                ; source index
--              inx
                ldy nt_rle_data,x       ; address high (0 = terminator)
                beq +
                inx
                lda nt_rle_data,x       ; address low
                jsr set_ppu_addr        ; Y, A -> address
                inx
                lda nt_rle_data,x       ; LLLLLLLV (LLLLLLL = length, V = vertical)
                lsr a
                tay                     ; length
                lda #0
                rol a
                asl a
                asl a
                sta ppu_ctrl            ; address autoincrement
                inx                     ; (%00000000 = 1 byte, %00000100 = 32 bytes)
                lda nt_rle_data,x       ; tile
-               sta ppu_data            ; write tile Y times
                dey
                bne -
                beq --                  ; next RLE block (unconditional)

+               jsr wait_vbl_start      ; wait until next VBlank starts
                jsr set_ppu_regs        ; set ppu_scroll and ppu_ctrl
                lda #%00011110          ; show sprites and background
                sta ppu_mask

                jmp main_loop

wait_vbl_start  bit ppu_status          ; wait until next VBlank starts
-               bit ppu_status
                bpl -
                rts

set_ppu_addr    sty ppu_addr            ; set PPU address from Y and A
                sta ppu_addr
                rts

set_ppu_regs    lda #$00                ; set ppu_scroll and ppu_ctrl
                sta ppu_scroll
                sta ppu_scroll
                lda #%10100000          ; enable NMI, use 8*16-pixel sprites
                sta ppu_ctrl
                rts

init_spr_attr   ; initial attributes for balls
                db %00000000, %01000000  ; subpalette 0, left/right half of ball
                db %00000001, %01000001  ; subpalette 1, left/right half of ball
                db %00000010, %01000010  ; subpalette 2, left/right half of ball
                db %00000011, %01000011  ; subpalette 3, left/right half of ball

init_x          ; initial X positions for balls
                ; minimum: 8 + 1 = 9
                ; maximum: 256 - 16 - 8 - 1 = 231
                ; Python 3: " ".join(format(n, "02x") for n in random.sample(range(9, 231+1), 24))
                hex 48 59 32 96 93 c6 26 70
                hex 31 d5 73 e6 3a 34 8c 52
                hex 1c 3d 61 c5 9e 88 b9 e7

init_inv_dirs   ; balls that initially move right/down instead of left/up
                hex c5 c9 cd d1 d7 db c1 c7 ce d5 d9 df
                hex e5 e9 ed f1 f7 fb e3 ea ef f3 f6 fd

bg_pal          ; background palette
                db col_bg0, col_bg1, col_bg2, col_bg3  ; screen border
                db col_bg0, col_bg0, col_bg0, col_bg0  ; unused
                db col_bg0, col_bg0, col_bg0, col_bg0  ; unused
                db col_bg0, col_bg0, col_bg0, col_bg0  ; unused

macro rle_run _y, _x, _length, _vertical, _tile
                ; RLE run (see nt_rle_data)
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

                ; move balls horizontally
                ; (all balls on even frames, all except last 8 on odd frames)
                ;
                ldx #(ball_count-1)     ; last ball to move -> loop_counter
                lda frame_count
                lsr a
                bcc +
                ldx #(ball_count-8-1)
+               stx loop_counter
                ;
-               ldx loop_counter        ; start loop
                ldy h_dir_addrs,x       ; direction address -> Y
                txa                     ; sprite data offset -> X
                asl a
                asl a
                asl a
                tax
                lda spr_data,y          ; get direction
                bpl +
                dec spr_data+3,x        ; move left; if hit wall, change direction & play sound
                dec spr_data+4+3,x
                lda spr_data+3,x
                cmp #8
                bne ++
                lda #%00000011          ; timer high = 3?
                sta sq1_hi
                lda #$00
                sta spr_data,y
                beq ++                  ; unconditional
+               inc spr_data+3,x        ; move right; if hit wall, change direction & play sound
                inc spr_data+4+3,x
                lda spr_data+3,x
                cmp #(256-16-8)
                bne ++
                lda #%00000011          ; timer high = 3?
                sta sq1_hi
                lda #$ff
                sta spr_data,y
++              dec loop_counter
                bpl -

                ; move all balls vertically
                lda #(ball_count-1)
                sta loop_counter
-               ldx loop_counter        ; start loop
                ldy v_dir_addrs,x       ; direction address -> Y
                txa                     ; offset in sprite data -> X
                asl a
                asl a
                asl a
                tax
                lda spr_data,y          ; get direction
                bpl +
                dec spr_data+0,x        ; move up; if hit wall, change direction & play sound
                dec spr_data+4+0,x
                lda spr_data+0,x
                cmp #(16-1)
                bne ++
                lda #%00000011          ; timer high = 3?
                sta sq2_hi
                lda #$00
                sta spr_data,y
                beq ++                  ; unconditional
+               inc spr_data+0,x        ; move down; if hit wall, change direction & play sound
                inc spr_data+4+0,x
                lda spr_data+0,x
                cmp #(240-16-16-1)
                bne ++
                lda #%00000011          ; timer high = 3?
                sta sq2_hi
                lda #$ff
                sta spr_data,y
++              dec loop_counter
                bpl -

                ; according to timer, copy one of two sprite palettes backwards from ROM to RAM
                ldx #16                 ; source offset (0/16) -> X
                lda frame_count
                and #(1<<blink_rate)
                bne +
                tax
+               ldy #(16-1)
-               lda spr_pals,x
                sta spr_pal,y
                inx
                dey
                bpl -

                inc frame_count         ; advance timer
                jmp main_loop

h_dir_addrs     hex  c1 c2 c3  c5 c6 c7  c9 ca cb  cd ce cf  ; horizontal direction addresses
                hex  d1 d2 d3  d5 d6 d7  d9 da db  dd de df
v_dir_addrs     hex  e1 e2 e3  e5 e6 e7  e9 ea eb  ed ee ef  ; vertical direction addresses
                hex  f1 f2 f3  f5 f6 f7  f9 fa fb  fd fe ff

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

                ldy #$3f                ; copy sprite palette backwards from RAM to VRAM
                lda #$10
                jsr set_ppu_addr        ; Y, A -> address
                ldx #(16-1)
-               lda spr_pal,x
                sta ppu_data
                dex
                bpl -

                bit ppu_status          ; reset ppu_addr/ppu_scroll latch
                jsr set_ppu_regs        ; set ppu_scroll and ppu_ctrl

                sec                     ; set MSB to let main loop run once
                ror run_main_loop

                pla                     ; pull Y, X, A
                tay
                pla
                tax
                pla

irq             rti

; --- Interrupt vectors ---------------------------------------------------------------------------

                pad $fffa, $ff
                dw nmi, reset, irq      ; note: IRQ unused

; --- CHR ROM -------------------------------------------------------------------------------------

                base $0000
                incbin "chr.bin"
                pad $2000, $ff

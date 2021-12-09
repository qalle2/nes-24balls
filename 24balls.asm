; 24 Balls (NES, ASM6)
; Note: indentation = 12 spaces, maximum length of identifiers = 11 characters.

; --- Constants -----------------------------------------------------------------------------------

; RAM
sprdata     equ $00    ; sprite data; see "zero page layout" below
spritepal   equ $0200  ; sprite palette (16 bytes, backwards)
runmainloop equ $0210  ; MSB = main loop allowed to run (0=no, 1=yes)
loopcounter equ $0211  ; loop counter
blinktimer  equ $0212  ; ball blink timer

; Zero page layout:
;   $00-$bf: visible sprites:
;       192 bytes = 24 balls * 2 sprites/ball * 4 bytes/sprite
;   $c0-$ff: hidden sprites:
;       Y positions ($c0, $c4, $c8, ...): always $ff
;       other bytes: directions of balls ($ff = up/left, $00 = down/right):
;           horizontal: $c1, $c2, $c3; $c5, $c6, $c7; ...; $dd, $de, $df
;           vertical:   $e1, $e2, $e3; $e5, $e6, $e7; ...; $fd, $fe, $ff

; memory-mapped registers; see http://wiki.nesdev.com/w/index.php/PPU_registers
ppuctrl     equ $2000
ppumask     equ $2001
ppustatus   equ $2002
oamaddr     equ $2003
ppuscroll   equ $2005
ppuaddr     equ $2006
ppudata     equ $2007
dmcfreq     equ $4010
oamdma      equ $4014
sndchn      equ $4015
joypad2     equ $4017

; background colors
colorbg0    equ $0f  ; background 0 (black)
colorbg1    equ $00  ; background 1 (dark gray)
colorbg2    equ $10  ; background 2 (gray)
colorbg3    equ $30  ; background 3 (white)

; screen border tiles
tilborderfu equ $01  ; border - full
tilbordertl equ $02  ; border - top left
tilbordert  equ $03  ; border - top
tilbordertr equ $04  ; border - top right
tilborderbl equ $05  ; border - bottom left
tilborderb  equ $06  ; border - bottom
tilborderbr equ $07  ; border - bottom right
tilborderl  equ $08  ; border - left
tilborderr  equ $09  ; border - right
tilball     equ $0a  ; ball (top left quarter; bottom left must immediately follow)

; misc
ballcnt     equ 24  ; number of balls
blinkrate   equ  3  ; ball blink rate (0=fastest, 7=slowest)

; --- iNES header ---------------------------------------------------------------------------------

            ; see https://wiki.nesdev.org/w/index.php/INES
            base $0000
            db "NES", $1a            ; file id
            db 1, 1                  ; 16 KiB PRG ROM, 8 KiB CHR ROM
            db %00000000, %00000000  ; NROM mapper, horizontal name table mirroring
            pad $0010, $00           ; unused

; --- Start of PRG ROM ----------------------------------------------------------------------------

            base $c000
            pad $fc00, $ff  ; last 1024 bytes of CPU memory space

; --- Initialization ------------------------------------------------------------------------------

reset       ; initialize the NES; see http://wiki.nesdev.com/w/index.php/Init_code
            sei             ; ignore IRQs
            cld             ; disable decimal mode
            ldx #%01000000
            stx joypad2     ; disable APU frame IRQ
            ldx #$ff
            txs             ; initialize stack pointer
            inx
            stx ppuctrl     ; disable NMI
            stx ppumask     ; disable rendering
            stx dmcfreq     ; disable DMC IRQs
            stx sndchn      ; disable sound channels

            bit ppustatus  ; wait until next VBlank starts
-           bit ppustatus
            bpl -

            lda #0            ; clear variables
            sta runmainloop
            sta blinktimer

            lda #$ff       ; fill sprite page with $ff (it will serve
            ldx #0         ; as invisible sprites' Y positions and as negative directions)
-           sta sprdata,x
            inx
            bne -

            ldx #0            ; sprite Y positions: 18 + ball_index * 8
-           txa
            clc
            adc #18
            sta sprdata,x
            sta sprdata+4,x
            txa
            clc
            adc #8
            tax
            cpx #(ballcnt*8)
            bne -

            lda #tilball      ; sprite tiles
            ldx #0
-           sta sprdata+1,x
            inx
            inx
            inx
            inx
            cpx #(ballcnt*8)
            bne -

            ldx #0             ; sprite attributes: subpalette = ball_index modulo 4,
--          ldy #0             ; horizontal flip = 1 for odd sprite indexes
-           lda initialattr,y  ; note: 6502 has STA ZP,X but no STA ZP,Y
            sta sprdata+2,x
            inx
            inx
            inx
            inx
            iny
            cpy #8
            bne -
            cpx #(ballcnt*8)
            bne --

            ldy #(ballcnt-1)   ; sprite X positions: from table
-           tya                ; note: 6502 has STA ZP,X but no STA ZP,Y
            asl
            asl
            asl
            tax
            lda initialx,y
            sta sprdata+3,x
            clc
            adc #8
            sta sprdata+4+3,x
            dey
            bpl -

            lda #$00           ; make some balls start moving right/down instead of left/up
            ldy #(ballcnt-1)   ; note: 6502 has STA ZP,X but no STA ZP,Y
-           ldx initinvdirs,y
            sta sprdata,x
            dey
            bpl -

            bit ppustatus  ; wait until next VBlank starts
-           bit ppustatus
            bpl -

            lda #$3f         ; set background palette
            sta ppuaddr
            ldx #$00
            stx ppuaddr
-           lda bgpalette,x
            sta ppudata
            inx
            cpx #16
            bne -

            lda #$20     ; clear name table 0 and attribute table 0
            sta ppuaddr
            lda #$00
            sta ppuaddr
            tax
            ldy #4
-           sta ppudata
            inx
            bne -
            dey
            bne -

            ; extract run-length encoded data to name table 0
            ldx #$ff         ; source index
--          inx
            lda ntrledata,x  ; address high (0 = terminator)
            beq +
            sta ppuaddr
            inx
            lda ntrledata,x  ; address low
            sta ppuaddr
            inx
            lda ntrledata,x  ; LLLLLLLV (LLLLLLL = length, V = vertical)
            lsr a
            tay              ; length
            lda #0
            rol a
            asl a
            asl a
            sta ppuctrl      ; address autoincrement (%00000000 = 1 byte, %00000100 = 32 bytes)
            inx
            lda ntrledata,x  ; tile
-           sta ppudata      ; write tile Y times
            dey
            bne -
            beq --           ; next RLE block (unconditional)

+           bit ppustatus  ; reset ppuaddr/ppuscroll latch
            lda #$00       ; reset PPU address and scroll
            sta ppuaddr
            sta ppuaddr
            sta ppuscroll
            sta ppuscroll

            bit ppustatus  ; wait until next VBlank starts
-           bit ppustatus
            bpl -

            lda #%10100000  ; enable NMI, use 8*16-pixel sprites
            sta ppuctrl
            lda #%00011110  ; show sprites and background
            sta ppumask

            jmp mainloop

initialattr ; initial attributes for balls
            db %00000000, %01000000  ; subpalette 0, left/right half of ball
            db %00000001, %01000001  ; subpalette 1, left/right half of ball
            db %00000010, %01000010  ; subpalette 2, left/right half of ball
            db %00000011, %01000011  ; subpalette 3, left/right half of ball

initialx    ; initial X positions for balls
            ; minimum: 8 + 1 = 9
            ; maximum: 256 - 16 - 8 - 1 = 231
            ; Python 3: " ".join(format(n, "02x") for n in random.sample(range(9, 231 + 1), 24))
            hex 48 59 32 96 93 c6 26 70
            hex 31 d5 73 e6 3a 34 8c 52
            hex 1c 3d 61 c5 9e 88 b9 e7

initinvdirs ; balls that initially move right/down instead of left/up
            hex c5 c9 cd d1 d7 db c1 c7 ce d5 d9 df
            hex e5 e9 ed f1 f7 fb e3 ea ef f3 f6 fd

bgpalette   ; background palette
            db colorbg0, colorbg1, colorbg2, colorbg3  ; screen border
            db colorbg0, colorbg0, colorbg0, colorbg0  ; unused
            db colorbg0, colorbg0, colorbg0, colorbg0  ; unused
            db colorbg0, colorbg0, colorbg0, colorbg0  ; unused

ntrledata   ; name table RLE data; 1 run = 4 bytes:
            ; - address high (0 = terminator)
            ; - address low
            ; - LLLLLLLV (LLLLLLL = length, V = vertical)
            ; - tile
            db $20, $00, 32*2+0, tilborderfu  ; first row (invisible)
            db $20, $20,  1*2+0, tilbordertl  ; border - top left
            db $20, $21, 30*2+0, tilbordert   ; border - top
            db $20, $3f,  1*2+0, tilbordertr  ; border - top right
            db $20, $40, 26*2+1, tilborderl   ; border - left
            db $20, $5f, 26*2+1, tilborderr   ; border - right
            db $23, $80,  1*2+0, tilborderbl  ; border - bottom left
            db $23, $81, 30*2+0, tilborderb   ; border - bottom
            db $23, $9f,  1*2+0, tilborderbr  ; border - bottom right
            db $23, $a0, 32*2+0, tilborderfu  ; last row (invisible)
            db $00

; --- Main loop -----------------------------------------------------------------------------------

mainloop    bit runmainloop  ; start of main loop; wait until NMI routine has set flag
            bpl mainloop
            lsr runmainloop  ; clear flag

            ; move balls horizontally (all balls on even frames, all except last 8 on odd frames)
            ldx #(ballcnt-1)    ; last ball to move -> loopcounter
            lda blinktimer
            and #%00000001
            beq +
            ldx #(ballcnt-8-1)
+           stx loopcounter
-           ldx loopcounter     ; start loop
            ldy hdiraddrs,x     ; direction address -> Y
            txa                 ; sprite data offset -> X
            asl
            asl
            asl
            tax
            lda sprdata,y       ; get direction
            bpl +
            dec sprdata+3,x     ; move left; if hit wall, change direction
            dec sprdata+4+3,x
            lda sprdata+3,x
            cmp #8
            bne ++
            lda #$00
            sta sprdata,y
            jmp ++
+           inc sprdata+3,x     ; move right; if hit wall, change direction
            inc sprdata+4+3,x
            lda sprdata+3,x
            cmp #(256-16-8)
            bne ++
            lda #$ff
            sta sprdata,y
++          dec loopcounter
            bpl -

            ; move all balls vertically
            lda #(ballcnt-1)
            sta loopcounter
-           ldx loopcounter     ; start loop
            ldy vdiraddrs,x     ; direction address -> Y
            txa                 ; offset in sprite data -> X
            asl
            asl
            asl
            tax
            lda sprdata,y       ; get direction
            bpl +
            dec sprdata+0,x     ; move up; if hit wall, change direction
            dec sprdata+4+0,x
            lda sprdata+0,x
            cmp #(16-1)
            bne ++
            lda #$00
            sta sprdata,y
            jmp ++
+           inc sprdata+0,x     ; move down; if hit wall, change direction
            inc sprdata+4+0,x
            lda sprdata+0,x
            cmp #(240-16-16-1)
            bne ++
            lda #$ff
            sta sprdata,y
++          dec loopcounter
            bpl -

            ; according to timer, copy one of two sprite palettes backwards from ROM to RAM
            ldx #16              ; source offset (0/16) -> X
            lda blinktimer
            and #(1<<blinkrate)
            bne +
            tax
+           ldy #(16-1)
-           lda spritepals,x
            sta spritepal,y
            inx
            dey
            bpl -

            inc blinktimer  ; advance timer
            jmp mainloop    ; end main loop

hdiraddrs   hex  c1 c2 c3  c5 c6 c7  c9 ca cb  cd ce cf  ; horizontal direction addresses
            hex  d1 d2 d3  d5 d6 d7  d9 da db  dd de df
vdiraddrs   hex  e1 e2 e3  e5 e6 e7  e9 ea eb  ed ee ef  ; vertical direction addresses
            hex  f1 f2 f3  f5 f6 f7  f9 fa fb  fd fe ff

spritepals  ; first set of sprite palettes (blue, red, yellow and green)
            db colorbg0, $11, $21, $31
            db colorbg0, $14, $24, $34
            db colorbg0, $17, $27, $37
            db colorbg0, $1a, $2a, $3a
            ; second set of sprite palettes (slightly different shades)
            db colorbg0, $12, $22, $32
            db colorbg0, $15, $25, $35
            db colorbg0, $18, $28, $38
            db colorbg0, $1b, $2b, $3b

; --- Interrupt routines --------------------------------------------------------------------------

nmi         pha  ; push A, X (note: not Y)
            txa
            pha

            lda #$00       ; do OAM DMA
            sta oamaddr
            lda #>sprdata
            sta oamdma

            lda #$3f         ; copy sprite palette backwards from RAM to VRAM
            sta ppuaddr
            lda #$10
            sta ppuaddr
            ldx #15
-           lda spritepal,x
            sta ppudata
            dex
            bpl -

            bit ppustatus  ; reset ppuaddr/ppuscroll latch
            lda #$00       ; reset PPU address and scroll
            sta ppuaddr
            sta ppuaddr
            sta ppuscroll
            sta ppuscroll

            sec              ; set flag to let main loop run once
            ror runmainloop

            pla  ; pull X, A
            tax
            pla

irq         rti  ; end interrupt routines; note: IRQ unused

; --- Interrupt vectors ---------------------------------------------------------------------------

            pad $fffa, $ff
            dw nmi, reset, irq  ; note: IRQ unused

; --- CHR ROM -------------------------------------------------------------------------------------

            base $0000
            incbin "chr.bin"
            pad $2000, $ff

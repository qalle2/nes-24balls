; 24 Balls - constants

; memory-mapped registers
ppu_ctrl   equ $2000
ppu_mask   equ $2001
ppu_status equ $2002
oam_addr   equ $2003
oam_data   equ $2004
ppu_scroll equ $2005
ppu_addr   equ $2006
ppu_data   equ $2007
dmc_freq   equ $4010
oam_dma    equ $4014
snd_chn    equ $4015
joypad1    equ $4016
joypad2    equ $4017

; RAM
sprite_page        equ $0000  ; see "zero page layout" below
timer              equ $0200
nmi_done           equ $0201  ; flag (only MSB is important)
loop_counter       equ $0202
sprite_palette_ram equ $0203  ; 16 bytes; backwards

; Zero page layout:
;   $00-$bf: visible sprites:
;       192 bytes = 24 balls * 2 sprites/ball * 4 bytes/sprite
;   $c0-$ff: hidden sprites:
;       Y positions ($c0, $c4, $c8, ...): always $ff
;       other bytes: directions of balls (negative = up/left, positive = down/right):
;           horizontal: $c1, $c2, $c3; $c5, $c6, $c7; ...; $dd, $de, $df
;           vertical:   $e1, $e2, $e3; $e5, $e6, $e7; ...; $fd, $fe, $ff

; joypad bitmasks
button_a      = %10000000
button_b      = %01000000
button_select = %00100000
button_start  = %00010000
button_up     = %00001000
button_down   = %00000100
button_left   = %00000010
button_right  = %00000001

; misc
ball_count equ 24


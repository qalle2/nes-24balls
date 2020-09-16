; 24 Balls - constants

; RAM
sprite_data        equ $0000  ; see "zero page layout" below
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

; colors
color_bg0 equ $0f  ; background 0 (black)
color_bg1 equ $00  ; background 1 (dark gray)
color_bg2 equ $10  ; background 2 (gray)
color_bg3 equ $30  ; background 3 (white)

; misc
ball_count equ 24
blink_rate equ 3    ; ball blink rate (0=fastest, 7=slowest)


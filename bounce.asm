;------------------------------------
; bounce.asm
; Animation of Angular Icons
; Copyright (c) 2022
; by David R. Van Wagner
; davevw.com
; MIT LICENSE - see file LICENSE
;------------------------------------

; Leverages https://github.com/davervw/hires-vic-20

; Thanks to 
;  https://archive.org/details/COMPUTEs_Mapping_the_VIC_1984_COMPUTE_Publications
;  built with 6502 assembler https://sourceforge.net/projects/acme-crossass/
;  Visual Code template https://github.com/Esshahn/acme-assembly-vscode-template
;  Visual Code extension (color syntax) https://marketplace.visualstudio.com/items?itemName=TonyLandi.acmecrossassembler

; expect hires20.ml @ a000-b7ff
; expect icons2 @ b000-b31f

;---- equates
icon_width   = 32
icon_height  = 40
icon_bytes   = (icon_width*icon_height/8)
icons        = $b000 ; shape data

;---- structure equates (offsets, etc.)
x1 = 0
y1 = 1
x2 = 2
y2 = 3
a1 = 4
b1 = 5
a2 = 6
b2 = 7
xd = 8
yd = 9
pos_bytes = 10 ; icon position struct size

;---- ROM externals
strout       = $cb1e ; PRTSTR
stop         = $ffe1

;---- hires externals
hires_init	    = $a0be
hires_color_at	= $a4f4
get_put_shape   = $a63d
switch_text	    = $a8c5
fill_graphics	= $aa27
multax	        = $ab35
param1          = $af68
param2          = param1+1
param3          = param2+1
param4          = param3+1
param5          = param4+1
resx	        = $af7c
resy	        = $af7d

*=$b9e1 ; SYS 47585

;---- main
start
    jsr text_splash

    ldy #120
    lda #0
    jsr call_delay

    jsr init_random

; initialize colors
    lda #8 ; multicolor, black foreground
    sta 646
    lda #$88 ; orange background ($80), not inverse ($08), black border ($00)
    sta $900F
    lda $900E
    and #$0F
    ora #$10 ; auxillary white
    sta $900E

; switch to graphics
    lda #192
    sta param1
    lda #160
    sta param2
    jsr hires_init

; fill border color (pretends to be background color)
    lda #$55
    jsr fill_graphics

; get initial locations of icons (non-overlap) and vectors
    jsr position_icons_non_overlap

; display icons
    ldx #0
-   jsr place_icon
    inx
    cpx #5
    bne -

; do
;   for each icon
;     check for stop, break
;     new_location = current + vector
;     if collision with other (not self)
;       reset vector
;     else
;       move icon to new_location
; repeat

--  lda #0
-   jsr save_icon_position
    jsr move_icon
    bcs ++
    jsr iterate_icons_for_collision
    bcs +
    tax
    jsr place_icon
    jmp +++
    ; on collision or out of bounds, backtrack and change direction
+   jsr restore_icon_position
++  jsr get_random_vector
    jsr set_icon_vector
+++ clc
    adc #1
    cmp #5
    bcc - ; next icon
    jsr stop
    bne -- ; repeat while STOP not pressed

; finish up

    ; wait for user to release STOP
-   jsr stop
    beq -

; restore colors to defaults
    lda #6 ; blue
    sta 646
    lda #$1B ; white background ($10), not inverse ($08), cyan border ($03)
    sta $900F

; graphics off - text
    jsr switch_text

; exit program to BASIC
    jmp text_splash

; ---- subroutines

; position icons (non-overlap)
position_icons_non_overlap

    ; initialize all off-screen, to guarantee outside bounding box
    lda #0
    ldx resx
    ldy resy
-   jsr set_icon_position
    clc
    adc #1
    cmp #5
    bne -

    ; randomize all icon positions, vectors
    lda #0
-   jsr get_random_coordinates
    jsr set_icon_position
    jsr iterate_icons_for_collision
    bcs -
    jsr get_random_vector
    jsr set_icon_vector
    clc
    adc #1
    cmp #5
    bne -
    rts

; place icon on screen with color
place_icon ; INPUT: .X = icon
    ; save registers
    pha
    txa
    pha
    tya
    pha

    txa
    tay ; store away icon number that multax will preserve

    ; get address of icon
    lda #icon_bytes
    jsr multax ; result in .A(lo),.X(hi)
    clc
    adc #<icons
    sta $fd
    clc
    txa
    adc #>icons
    sta $fe

    tya
    jsr mult10
    tax
    lda icon_position+x1,x
    sta param1
    lda icon_position+y1,x
    sta param2
    lda icon_position+x2,x
    sta param3
    lda icon_position+y2,x
    sta param4

    jsr save_params

    lda icon_color,y
    sta param5
    jsr hires_color_at

    jsr restore_params
    lda #1
    sta param5 ; PUT
    jsr get_put_shape

    ; restore registers
    pla
    tay
    pla
    tax
    pla

    rts

; initialize random number generator from jiffy clock
init_random
    clc
    lda $A0
    adc $A1
    adc $A2
lda #0 ; TODO: FOR REPEATABILITY - REMOVE AFTER R&D TESTING
    sta random_index
    rts    

; get next random byte
    ; INPUTS: none (.X/.Y preserved)
    ; OUTPUTS: .A random value
get_next_random_byte
    stx tempx
    ldx random_index
    lda random_bytes,x
    inx
    stx random_index
    ldx tempx
    rts

; get random coordinates
    ; INPUTS: none (preserves .A)
    ; OUTPUTS: .X/.Y coordinates
get_random_coordinates
    pha
    jsr get_next_random_byte
    tax
    sec
    lda resy
    sbc #icon_height
    jsr multax ; result in .A(lo),.X(hi)
    txa
    tay
    jsr get_next_random_byte
    tax
    sec
    lda resx
    sbc #icon_width
    jsr multax ; result in .A(lo),.X(hi)
    txa
    and #$fe
    tax
    pla
    rts

; get random directions
get_random_vector
    ; INPUTS: none (preserves .A)
    ; OUTPUTS: .X/.Y directions -4 to +4 each (signed byte)
    ;          .X will be even
    pha
-   jsr get_next_random_byte
    ldx #9
    jsr multax ; result in .A(lo),.X(hi) for random treating as a fraction result in .X, discard .A
    txa ; result is 0..8
    sec
    sbc #4
    tay
    jsr get_next_random_byte
    ldx #5
    jsr multax ; result in .A(lo),.X(hi)
    txa ; result is 0..4
    asl ; ensure is even number for multicolor requirements (keep x coordinate even), result is 0..8
    sec
    sbc #4
    tax
    sty temp
    ora temp
    beq - ; try again if not moving
    pla
    rts

; get icon position
;   INPUTS: .A = icon# (preserved)
;   OUTPUTS: .X/.Y = x1/y1
get_icon_position
    sta temp

    jsr mult10
    tax

    lda icon_position+y1,x
    tay
    lda icon_position+x1,x
    tax

    lda temp

    rts

; get icon vector
;   INPUTS: .A = icon# (preserved)
;   OUTPUTS: .X/.Y = xd/yd
get_icon_vector
    sta temp

    jsr mult10
    tax

    lda icon_position+yd,x
    tay
    lda icon_position+xd,x
    tax

    lda temp

    rts

; set icon position
;   INPUTS: .A = icon#, .X/.Y = x1/y1 (all preserved)
;   OUTPUTS: updates icon_position including image bounding box and color bounding box
set_icon_position
    pha

    ; convert icon number to address index
    jsr mult10

    ; swap A <=> X
    sta temp
    txa
    ldx temp

    sta icon_position+x1,x
    tya    
    sta icon_position+y1,x
    
    clc
    lda icon_position+x1,x
    adc #icon_width-1
    sta icon_position+x2,x
    lda icon_position+y1,x
    adc #icon_height-1
    sta icon_position+y2,x

    lda icon_position+x1,x
    and #$f8
    sta icon_position+a1,x
    lda icon_position+y1,x
    and #$f0
    sta icon_position+b1,x

    lda icon_position+x2,x
    adc #7
    and #$f8
    sta icon_position+a2,x
    lda icon_position+y2,x
    adc #15
    and #$f0
    sta icon_position+b2,x

    lda icon_position+y1,x
    tay
    lda icon_position+x1,x
    tax

    pla

    rts

save_icon_position
    ; INPUTS: .A = icon# (all preserved)
    ; OUTPUTS: icon position structure copied to 6th position
    pha
    jsr get_icon_position
    lda #5
    jsr set_icon_position
    pla
    rts

restore_icon_position
    ; INPUTS: .A = icon# (all preserved)
    ; OUTPUTS: icon position structure copied from 6th position
    pha
    lda #5
    jsr get_icon_position
    pla
    jsr set_icon_position
    rts

; set icon vector (direction)
;   INPUTS: .A = icon#, .X/.Y = dx/dy (all preserved)
;   OUTPUTS: updates direction bytes within icon_position structure
set_icon_vector
    pha

    ; convert icon number to address index
    jsr mult10

    ; swap A <=> X
    sta temp
    txa
    ldx temp

    sta icon_position+xd,x
    tya    
    sta icon_position+yd,x
    
    lda icon_position+xd,x
    tax

    pla

    rts

; iterate icons for collision
iterate_icons_for_collision
    ; INPUTS: .a=index to check (preserves all registers)
    ; OUTPUTS: C flag set = collision, clear = none

    ; save registers
    sta check1_index
    txa
    pha
    tya
    pha

    ldx check1_index
    lda #0 ; icon iterator
-   cmp check1_index
    beq + ; don't collide with self
    sta check2_index
    jsr check_two_icons_for_collision
    bcs ++
+   clc
    adc #1 ; increment iterator
    cmp #5 ; last icon?
    bne - ; loop until done
    clc

++  ; carry has result

    ; restore registers
+   pla
    tay
    pla
    tax
    lda check1_index

    rts

; check two icons for collision
check_two_icons_for_collision
    ; INPUTS: check1_index,check2_index indxes to compare (all preserved)
    ; OUTPUTS: C flag set = okay, clear = collision

    ; save registers
    pha
    txa
    pha
    tya
    pha

    lda check1_index
    jsr mult10
    tax
    lda check2_index
    jsr mult10
    tay
    ; .X=byte offset to first icon position
    ; .Y=byte offset to second icon position

    ; for the four coordinates of first icon
    ;    look if in bounding box of second icon

    ; first.topleft within second icon?
    lda icon_position+a2,y
    cmp icon_position+a1,x
    bcc + ; no
    lda icon_position+a1,x
    cmp icon_position+a1,y
    bcc + ; no
    lda icon_position+b2,y
    cmp icon_position+b1,x
    bcc + ; no
    lda icon_position+b1,x
    cmp icon_position+b1,y
    bcs ++ ; yes
+
    ; first.topright within second icon?
    lda icon_position+a2,y
    cmp icon_position+a2,x
    bcc + ; no
    lda icon_position+a2,x
    cmp icon_position+a1,y
    bcc + ; no
    lda icon_position+b2,y
    cmp icon_position+b1,x
    bcc + ; no
    lda icon_position+b1,x
    cmp icon_position+b1,y
    bcs ++ ; yes
+
    ; first.bottomleft within second icon?
    lda icon_position+a2,y
    cmp icon_position+a1,x
    bcc + ; no
    lda icon_position+a1,x
    cmp icon_position+a1,y
    bcc + ; no
    lda icon_position+b2,y
    cmp icon_position+b2,x
    bcc + ; no
    lda icon_position+b2,x
    cmp icon_position+b1,y
    bcs ++ ; yes
+
    ; first.bottomright within second icon?
    lda icon_position+a2,y
    cmp icon_position+a2,x
    bcc ++ ; no
    lda icon_position+a2,x
    cmp icon_position+a1,y
    bcc ++ ; no
    lda icon_position+b2,y
    cmp icon_position+b2,x
    bcc ++ ; no
    lda icon_position+b2,x
    cmp icon_position+b1,y
++
    ; result is in Carry flag set=collision, clear=none 

    ; restore registers
    pla
    tay
    pla
    tax
    pla

    rts

; move icon
move_icon
    ; INPUTS: .A=icon index# (A preserved)
    ; OUTPUTS: C set if out of bounds
    pha

    jsr get_icon_position
    stx tempx
    sty tempy
    jsr get_icon_vector
    txa
    clc
    adc tempx
    tax
    cmp resx ; compare left with horizontal resolution
    bcs ++
    adc #icon_width
    cmp resx ; compare right with horizontal resolution
    bcs ++
    tya
    clc
    adc tempy
    tay
    cmp resy ; compare top with vertical resolution
    bcs ++
    adc #icon_height
    cmp resy ; compare bottom with vertical resolution
    bcs ++

    ; within bounds
    pla
    jmp set_icon_position

++  ; out of bounds
    pla
    rts

; text splash
text_splash
    lda #<credits
    ldy #>credits
    jmp strout

; call delay
call_delay
    ; set alarm with interrupts on during critical part, avoiding rollover
    clc
    pha ; save bits 8..15
	tya ; transfer bits 0..7
    sei
    adc $A2
	sta alarm+2
    pla ; restore bits 8..15
    adc $A1
    sta alarm+1
    lda $A0
    cli
    adc #0
    sta alarm
 
    ; check for alarm, busy wait, highest byte down, assume interrupts off is fine, will wait for any rollover
    lda alarm
-   cmp $A0
    bne -
    lda alarm+1
-   cmp $A1
    bne -
    lda alarm+2
-   cmp $A2
    bne -

    rts

save_params
    lda param1
    sta save_param1
    lda param2
    sta save_param2
    lda param3
    sta save_param3
    lda param4
    sta save_param4
    lda param5
    sta save_param5
    lda $fd
    sta save_addr
    lda $fe
    sta save_addr+1
    rts

restore_params
    lda save_param1
    sta param1
    lda save_param2
    sta param2
    lda save_param3
    sta param3
    lda save_param4
    sta param4
    lda save_param5
    sta param5
    lda save_addr
    sta $fd
    lda save_addr+1
    sta $fe
    rts

mult10
    ; INPUTS: .A value (.X,.Y preserved)
    ; OUTPUTS: .A * 10
    stx tempx
    ldx #10
    jsr multax
    ldx tempx
    rts

; ---- data
credits
    !byte 147
    !byte 18
    !text "ANGULAR ANIMATION"
    !byte 13
    !text "COPYRIGHT (C) 2022"
    !byte 13
    !text "BY DAVID VAN WAGNER"
    !byte 13, 13

    !byte 18
    !text "VIC-20 HIRES"
    !byte 13
    !text "COPYRIGHT (C) 2022"
    !byte 13
    !text "BY DAVID VAN WAGNER"
    !byte 13, 13

    !text "DAVEVW.COM"
    !byte 13
    !text "MIT LICENSE"
    !byte 13
    !byte 0


alarm
    !byte 0,0,0

icon_color
    !byte 0+8
    !byte 6+8
    !byte 2+8
    !byte 6+8
    !byte 7+8

save_param1 !byte 0
save_param2 !byte 0
save_param3 !byte 0
save_param4 !byte 0
save_param5 !byte 0
save_addr !byte 0,0

random_index !byte 0

; random data - 256 bytes shuffled
random_bytes
    !byte $9a, $ec, $a8, $66, $99, $ca, $bb, $04, $3a, $ba, $ab, $83, $5a, $2a, $20, $2d
    !byte $59, $15, $b0, $cc, $56, $7d, $db, $46, $af, $52, $47, $13, $d8, $1e, $36, $7e
    !byte $f4, $45, $e3, $9e, $b6, $29, $67, $a9, $85, $44, $a7, $d7, $27, $71, $58, $89
    !byte $b2, $ad, $97, $d4, $02, $41, $a2, $ee, $65, $eb, $81, $f9, $8c, $c4, $48, $b1
    !byte $49, $bf, $55, $e5, $40, $e4, $26, $7b, $f3, $8a, $51, $31, $2e, $6e, $1d, $f2
    !byte $e0, $80, $a1, $37, $4f, $03, $5f, $79, $b9, $19, $5e, $a0, $a6, $5b, $33, $c9
    !byte $b3, $ff, $17, $86, $3b, $76, $77, $8e, $2b, $9b, $92, $3c, $ac, $75, $c3, $06
    !byte $64, $c0, $96, $22, $73, $e9, $38, $fe, $e1, $42, $68, $2c, $c6, $3e, $ed, $8b
    !byte $30, $d6, $9f, $11, $91, $05, $8f, $43, $09, $f5, $00, $88, $4d, $74, $8d, $9d
    !byte $72, $63, $c2, $50, $b7, $70, $aa, $ea, $54, $bd, $3d, $cd, $cf, $0a, $c7, $fb
    !byte $16, $61, $d0, $c1, $a5, $25, $1f, $f0, $fd, $1a, $4b, $b5, $21, $53, $84, $e6
    !byte $dd, $6c, $e2, $df, $01, $9c, $6b, $4c, $94, $4a, $93, $d1, $62, $23, $d3, $de
    !byte $3f, $0b, $fa, $e7, $69, $ef, $87, $2f, $82, $57, $1c, $f8, $0d, $7c, $4e, $5d
    !byte $14, $34, $d2, $ce, $0f, $08, $0e, $10, $90, $60, $7a, $24, $d5, $bc, $7f, $e8
    !byte $07, $6a, $da, $18, $5c, $1b, $c8, $f6, $28, $ae, $0c, $f7, $f1, $be, $35, $dc
    !byte $6f, $cb, $98, $32, $c5, $12, $fc, $6d, $78, $b4, $a4, $95, $b8, $39, $d9, $a3

icon_position ; structures for 6 icons
    ; topleft: x1, y1, bottomright: x2, y2, 
    ; colortopleft: a1, a2
    ; colorbottomright: b1, b2
    ; vector (xdelta, ydelta): xd, yd
    ; x1, y1, x2, y2, a1, a2, b1, b2, xd, yd (10 bytes)
    !byte 0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0
    !byte 0,0,0,0,0,0,0,0,0,0

temp !byte 0
tempx !byte 0
tempy !byte 0

check1_index !byte 0
check2_index !byte 0

icon_blank ; icon data, border color that simulates background
    !byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
    !byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
    !byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
    !byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55
    !byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55

finish

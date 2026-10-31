; Standalone native background-scroll viewer.
; Build from this directory with: mads Exile-background-scroll-test.asm -o:Exile-background-scroll-test.xex
; Joystick 0: up/down/left/right scroll one native character cell per update.
; This file keeps the world background lookup, native sprite plotter, LMS ring,
; incremental dirty-cell redraw, and required map/sprite assets only.

skctl	equ $d20f
porta	equ $d300 ;stick 0,1
portb	equ $d301
dmactl	equ $d400
dlistl	equ $d402
chbase	equ $d409
nmien	equ $d40e
nmist	equ $d40f
square_is_mapped_data=$00
square_sprite=$08
square_orientation=$09
f3_xy=$0F
f2_xy=$10                       ; also used in plotting
background_processing_flag=$2D
this_object_x_low=$4F
this_object_x_low_old=$50
this_object_y_low=$51
this_object_y_low_old=$52
this_object_x=$53
this_object_x_old=$54
this_object_y=$55
this_object_y_old=$56
this_object_flipping_flags=$71
this_object_flipping_flags_old=$72
this_object_palette=$73
this_object_palette_old=$74
this_object_sprite=$75
this_object_sprite_old=$76
square_x=$95
square_y=$97
zp_various_9c=$9C
zp_various_9d=$9D
map_address=$A4
map_address_high=$A5
new_object_data_pointer=$BD
new_object_type_pointer=$BE
screen_start_square_x_low=$C7
screen_start_square_x=$C8
screen_start_square_y_low=$C9
screen_start_square_y=$CA
vbi_ptr	equ $e6
dli_ptr	equ $e8

	org $2000
palette_register_updating
    dta 0
scroll_test_start
    SEI
    LDA #$00
    STA nmien
    LDA #$FE
    STA portb
    LDA #$03
    STA skctl
    LDA #<m4_dl
    STA dlistl
    LDA #>m4_dl
    STA dlistl+1
    LDA #<nmi_handler
    STA $FFFA
    LDA #>nmi_handler
    STA $FFFB
    LDA #<m4_dli
    STA dli_ptr
    LDA #>m4_dli
    STA dli_ptr+1
    LDA #<scroll_test_vbi
    STA vbi_ptr
    LDA #>scroll_test_vbi
    STA vbi_ptr+1
    LDA #$80
    STA screen_start_square_x_low
    LDA #$97
    STA screen_start_square_x
    LDA #$00
    STA screen_start_square_y_low
    LDA #$3A
    STA screen_start_square_y
    JSR m4_game_scroll_prepare
    JSR m4_game_lms_patch
    JSR m4_game_charset_patch
    LDA m4_charset_pages
    STA chbase
    LDA #$3D
    STA dmactl
    LDA #$C0
    STA nmien
    JMP m4_background_scroll_test_init
nmi_handler
    BIT nmist
    BPL scroll_test_vbi
    JMP (dli_ptr)
scroll_test_vbi
    PHA
    TXA
    PHA
    TYA
    PHA
    INC palette_register_updating
    LDA #1
    STA m4_dli_index
    JSR m4_game_lms_patch
    JSR m4_game_charset_patch
    LDA m4_charset_pages
    STA chbase
    PLA
    TAY
    PLA
    TAX
    PLA
    RTI
m4_background_scroll_test_init
    LDA #$80
    STA screen_start_square_x_low
    LDA #$97
    STA screen_start_square_x
    LDA #0
    STA screen_start_square_y_low
    LDA #$3A
    STA screen_start_square_y
    LDA #0
    STA m4_incremental_initialized
    STA m4_incremental_clip
    JSR m4_game_scroll_prepare
    JSR m4_game_lms_patch
    JSR m4_game_charset_patch
m4_background_scroll_test_loop
    LDA #0
    STA palette_register_updating
m4_background_scroll_test_wait_vbi
    LDA palette_register_updating
    BEQ m4_background_scroll_test_wait_vbi
    JSR m4_background_scroll_test_move
    BCS m4_background_scroll_test_render
    LDA m4_background_scroll_test_rendered
    BNE m4_background_scroll_test_loop
m4_background_scroll_test_render
    JSR m4_game_scroll_prepare
    JSR m4_game_lms_patch
    JSR m4_incremental_prepare
    JSR m4_game_charset_patch
    LDA m4_incremental_full_frame
    BEQ m4_background_scroll_test_dirty
    LDA #0
    STA m4_incremental_clip
    JSR clear_charsets
    JSR bg_tiles_test
    JMP m4_background_scroll_test_render_done
m4_background_scroll_test_dirty
    JSR m4_incremental_clear_dirty
    LDA #1
    STA m4_incremental_clip
    JSR bg_tiles_test
    LDA #0
    STA m4_incremental_clip
m4_background_scroll_test_render_done
    LDA #1
    STA m4_background_scroll_test_rendered
    JMP m4_background_scroll_test_loop
m4_background_scroll_test_move
    LDA porta
    EOR #$0F
    STA m4_background_scroll_test_input
    LDA #0
    STA m4_background_scroll_test_changed
    LDA m4_background_scroll_test_input
    AND #$01
    BEQ m4_background_scroll_test_down
    SEC
    LDA screen_start_square_y_low
    SBC #$40
    STA screen_start_square_y_low
    LDA screen_start_square_y
    SBC #0
    STA screen_start_square_y
    INC m4_background_scroll_test_changed
m4_background_scroll_test_down
    LDA m4_background_scroll_test_input
    AND #$02
    BEQ m4_background_scroll_test_left
    CLC
    LDA screen_start_square_y_low
    ADC #$40
    STA screen_start_square_y_low
    LDA screen_start_square_y
    ADC #0
    STA screen_start_square_y
    INC m4_background_scroll_test_changed
m4_background_scroll_test_left
    LDA m4_background_scroll_test_input
    AND #$04
    BEQ m4_background_scroll_test_right
    SEC
    LDA screen_start_square_x_low
    SBC #$40
    STA screen_start_square_x_low
    LDA screen_start_square_x
    SBC #0
    STA screen_start_square_x
    INC m4_background_scroll_test_changed
m4_background_scroll_test_right
    LDA m4_background_scroll_test_input
    AND #$08
    BEQ m4_background_scroll_test_move_done
    CLC
    LDA screen_start_square_x_low
    ADC #$40
    STA screen_start_square_x_low
    LDA screen_start_square_x
    ADC #0
    STA screen_start_square_x
    INC m4_background_scroll_test_changed
m4_background_scroll_test_move_done
    LDA m4_background_scroll_test_changed
    BEQ m4_background_scroll_test_no_move
    SEC
    RTS
m4_background_scroll_test_no_move
    CLC
    RTS
m4_background_scroll_test_input
    dta 0
m4_background_scroll_test_changed
    dta 0
m4_background_scroll_test_rendered
    dta 0

; World background palette and sprite lookup data.
background_sprite_lookup
;;  $ $7f = sprite
;;  $ $80 = vertically flipped
;;       0   1    2  3   4   5   6   7   8   9   a   b   c   d   e   f
    dta $C6,$CE,$C6,$C6,$C6,$BB,$C6,$18,$2D,$70,$6A,$C6,$23,$39,$C6,$62 ; 0
    dta $C0,$8E,$39,$44,$47,$26,$48,$49,$DF,$C6,$99,$9A,$25,$2B,$39,$3B ; 1
    dta $3C,$55,$8E,$43,$34,$35,$27,$28,$29,$2A,$42,$BF,$40,$3D,$38,$36 ; 2
    dta $37,$3E,$33,$31,$2F,$30,$2C,$24,$32,$41,$45,$3A,$6A,$23,$60,$CC ; 3
background_y_offset_lookup
;;       0   1    2  3   4   5   6   7   8   9   a   b   c   d   e   f
    dta $00,$00,$00,$00,$00,$00,$00,$D0,$C5,$B0,$C7,$00,$06,$00,$00,$C0 ; 0
    dta $B0,$A0,$07,$08,$00,$04,$80,$C0,$70,$00,$B0,$80,$99,$08,$00,$80 ; 1
    dta $C0,$00,$A0,$03,$02,$82,$01,$41,$81,$C1,$04,$F0,$B0,$00,$03,$02 ; 2
    dta $82,$70,$06,$C0,$C5,$04,$80,$06,$80,$04,$99,$30,$C7,$06,$A9,$00 ; 3
background_palette_lookup
;;       0   1    2  3   4   5   6   7   8   9   a   b   c   d   e   f
    dta $80,$02,$91,$91,$91,$00,$91,$A8,$DC,$B8,$8C,$80,$C9,$4A,$80,$06 ; 0
    dta $88,$05,$04,$00,$02,$02,$02,$02,$02,$91,$03,$03,$02,$02,$00,$00 ; 1
    dta $00,$BC,$B1,$00,$00,$00,$01,$01,$01,$01,$00,$04,$04,$04,$04,$04 ; 2
    dta $04,$04,$02,$01,$01,$01,$02,$02,$02,$00,$00,$00,$82,$02,$64,$EE ; 3
background_wall_y_start_base_lookup
;;       0   1    2  3   4   5   6   7   8   9   a   b   c   d   e   f
    dta $0F,$3A,$0F,$0F,$0F,$77,$0F,$F0,$B0,$F0,$C0,$0F,$00,$F0,$0F,$F0 ; 0
    dta $0F,$0F,$00,$06,$0F,$00,$77,$B3,$0F,$0F,$0F,$0F,$90,$06,$0F,$77 ; 1
    dta $B3,$F0,$0F,$10,$07,$70,$0B,$37,$73,$B0,$00,$0F,$B3,$0F,$10,$07 ; 2
    dta $70,$77,$00,$B3,$B0,$00,$77,$00,$77,$00,$90,$2C,$C0,$00,$90,$0F ; 3
background_wall_y_start_lookup
;;  Add $100 to get address in wall_base_y_lookup
;;        --  -V  H-  HV
    dta $00,$00,$00,$00
    dta $08,$40,$40,$08
    dta $10,$48,$48,$10
    dta $18,$50,$50,$18
    dta $38,$20,$70,$58
    dta $38,$78,$70,$80
    dta $30,$60,$68,$28
    dta $88,$90,$88,$90
    dta $A0,$50,$98,$18
    dta $18,$98,$50,$A0
background_objects_range_minus_one
    dta $00
background_objects_range
;;  [TOM background_objects_range 1d was 19]
    dta $1D,$39,$57,$7A,$9E,$BC,$D8,$F6,$FE
background_objects_data_offset
;        +1  -2  -5  -6  -8  -11 -11 -13 -13
    dta $01,$FE,$FB,$FA,$F8,$F5,$F5,$F3,$F3
background_objects_type_offset
    dta $00,$F5,$E9,$DE,$CE,$BE,$B1,$A1,$98
background_objects_x_lookup
;        0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f   10  11  12  13  14  15  16  17  18  19  1a  1b  1c
    dta $FF,$FF,$B0,$EC,$77,$64,$9A,$AF,$DA,$C6,$36,$9F,$2E,$A9,$9C,$83,$88,$5F,$57,$BF,$9D,$4D,$45,$81,$B3,$3F,$CB,$40,$4C
;        1d  1e  1f  20  21  22  23  24  25  26  27  28  29  2a  2b  2c  2d  2e  2f  30  31  32  33  34  35  36  37  38
    dta $CA,$2F,$A7,$56,$34,$E3,$3B,$E4,$80,$E0,$64,$37,$47,$9F,$9C,$AA,$9B,$9A,$5E,$C7,$8A,$60,$9D,$A2,$B2,$98,$A9,$DB
;        39  3a  3b  3c  3d  3e  3f  40  41  42  43  44  45  46  47  48  49  4a  4b  4c  4d  4e  4f  50  51  52  53  54  55  56
    dta $28,$29,$3C,$98,$63,$CB,$61,$A3,$CE,$E9,$80,$2E,$4F,$79,$87,$B6,$97,$2D,$D6,$5C,$A0,$74,$6A,$A1,$9F,$89,$85,$6B,$AE,$65
;        57  58  59  5a  5b  5c  5d  5e  5f  60  61  62  63  64  65  66  67  68  69  6a  6b  6c  6d  6e  6f  70  71  72  73  74  75  76  77  78  79
    dta $E2,$ED,$80,$CD,$A8,$2B,$AB,$9D,$62,$E5,$70,$EC,$83,$C1,$C6,$67,$EB,$2D,$98,$AA,$CC,$A5,$9E,$A2,$D7,$E6,$E7,$94,$7C,$E3,$45,$9B,$9F,$C2,$71
;        7a  7b  7c  7d  7e  7f  80  81  82  83  84  85  86  87  88  89  8a  8b  8c  8d  8e  8f  90  91  92  93  94  95  96  97  98  99  9a  9b  9c  9d
    dta $67,$4F,$CF,$D2,$E2,$7A,$62,$DA,$76,$B2,$66,$D7,$83,$84,$80,$87,$9B,$50,$AE,$64,$A3,$63,$B8,$7F,$82,$E0,$9C,$61,$9D,$29,$46,$9F,$9A,$74,$75,$77
;        9e  9f  a0  a1  a2  a3  a4  a5  a6  a7  a8  a9  aa  ab  ac  ad  ae  af  b0  b1  b2  b3  b4  b5  b6  b7  b8  b9  ba  bb
    dta $B2,$E4,$62,$63,$82,$61,$D4,$D3,$77,$2E,$64,$86,$A5,$A0,$D1,$B4,$7F,$A3,$9F,$99,$80,$67,$DA,$89,$95,$8B,$AB,$C4,$9D,$AA
;        bc  bd  be  bf  c0  c1  c2  c3  c4  c5  c6  c7  c8  c9  ca  cb  cc  cd  ce  cf  d0  d1  d2  d3  d4  d5  d6  d7
    dta $BB,$47,$8A,$A7,$61,$9E,$2E,$D6,$7E,$DA,$AA,$AB,$45,$67,$D4,$29,$B8,$6B,$69,$9D,$94,$63,$B4,$A1,$9F,$A0,$57,$E1
;        d8  d9  da  db  dc  dd  de  df  e0  e1  e2  e3  e4  e5  e6  e7  e8  e9  ea  eb  ec  ed  ee  ef  f0  f1  f2  f3  f4  f5
    dta $7F,$A6,$B4,$53,$61,$D4,$82,$E3,$75,$C3,$84,$9E,$C6,$64,$A2,$28,$29,$9D,$83,$A8,$80,$AA,$D5,$A0,$9F,$D6,$62,$69,$2C,$A5
;        f6  f7  f8  f9  fa  fb  fc  fd
    dta $B8,$B9,$D9,$59,$79,$39,$48,$E8
;        fe
    dta $03

background_objects_handler_lookup
    dta $89,$89,$89,$89,$89,$8A,$46,$C6,$06,$06,$46,$05,$05,$00,$C3,$04
    dta $83,$84,$84,$83,$88,$48,$02,$02,$42,$02,$7B,$22,$1E,$06,$06,$C6
    dta $06,$46,$46,$85,$85,$87,$89,$89,$C7,$0A,$8C,$03,$84,$83,$43,$84
    dta $84,$02,$01,$41,$01,$01,$2E,$1E,$3B,$46,$46,$06,$C6,$06,$06,$06
    dta $46,$06,$09,$C9,$89,$CA,$8A,$8A,$0A,$4A,$8A,$04,$44,$41,$01,$C8
    dta $48,$CC,$82,$02,$02,$02,$1E,$89,$09,$0A,$4A,$CA,$4A,$86,$46,$46
    dta $46,$86,$45,$47,$00,$00,$00,$00,$84,$C3,$44,$43,$43,$43,$44,$84
    dta $44,$04,$01,$08,$08,$02,$02,$82,$1E,$2D,$46,$46,$45,$46,$C6,$89
    dta $C9,$49,$89,$CA,$CA,$8A,$8A,$8A,$0A,$00,$00,$C4,$43,$04,$43,$84
    dta $44,$04,$44,$84,$41,$01,$01,$01,$C8,$42,$82,$3B,$11,$3B,$89,$C9
    dta $CA,$8A,$C6,$06,$C6,$C6,$06,$06,$85,$47,$4A,$CA,$8A,$00,$00,$44
    dta $43,$C3,$44,$44,$04,$41,$C8,$88,$C8,$C8,$02,$8C,$49,$89,$0A,$0A
    dta $8A,$C6,$06,$06,$47,$87,$CC,$41,$01,$08,$08,$08,$08,$C4,$84,$43
    dta $43,$84,$04,$83,$82,$82,$0D,$0D,$46,$06,$06,$06,$06,$45,$45,$45
    dta $06,$07,$89,$09,$8A,$4A,$4A,$CA,$CA,$4A,$00,$00,$00,$48,$08,$82
    dta $82,$82,$02,$C4,$C4,$0B,$0B,$0B,$D1,$91,$D1,$D1,$91,$91,$0D

; Map each legacy palette value to the native two-bit pixel colors.
palette_value_to_pixel_lookup
	dta $CA                        ; yellow bg, black bg
	dta $C9                        ; green bg, red bg
	dta $E3                        ; magenta bg, red bg
	dta $E9                        ; cyan bg, red bg
	dta $EB                        ; white bg, red bg
	dta $CE                        ; yellow bg, green bg
	dta $F8                        ; cyan bg, blue bg
	dta $E6                        ; magenta bg, green bg
	dta $CC                        ; green bg, green bg
	dta $EE                        ; white bg, green bg
	dta $30                        ; blue fg, blue fg
	dta $DE                        ; yellow bg, cyan bg
	dta $EF                        ; white bg, yellow bg
	dta $CB                        ; yellow bg, red bg

background_lookup
    dta $19,$2D,$ED,$6D,$AD,$2D,$ED
    dta $5E,$9E,$00,$C0,$80,$40
    dta $2E,$2F,$2E,$23; [TOM 2f was 2e]
    dta $06,$04,$06,$04,$07,$05,$05,$06,$19,$2C,$19,$2B,$00,$01,$02,$03
    dta $1A,$21,$09,$9B,$12,$10,$60,$2B,$0F,$4F,$04,$0A
lookup_for_unmatched_hash
    dta $1B,$5A,$19,$19,$1E,$13,$24,$2C,$19
wall_palette_zero_lookup
;;  lookup table for Y -> palette for background
    dta $8D,$82,$8B,$8F,$84,$89,$8D
wall_palette_four_lookup
    	dta $81,$82,$81,$85
	dta $B2
	dta $CD
	dta $90
	dta $95
	dta $81
wall_palette_three_lookup
    dta $B1,$97,$FD,$F3

; Resolve the real map tile and background-object hash without running handlers.
determine_background
    LDX #$00
    STX new_object_data_pointer
    STX square_is_mapped_data
    JSR calculate_background
    STA square_sprite
    AND #$C0
    STA square_orientation      ;
    EOR square_sprite           ; = calculate_background $3f
    CMP #$09
    BCS no_background_object

; is there a hash table point in this square?

    STA zp_various_9d ; background_object_number
    TAY               ; a = 0 - 8
    LDX background_objects_range,Y ; use background_objects_range to
                                   ; determine where to look
    LDA background_objects_x_lookup,X ; in background_objects_x_lookup

; Try to find square_x in the table. The range to search is from
; (background_objects_range-1)[X] (inclusive) to
; background_objects_range[X] (exclusive). To simplify the loop
; condition, use a sentinel: set background_objects_range[X] to
; square_x. Check after the loop whether it was an actual entry that
; was found, or the sentinel.

    PHA                  ; backup value of background_objects_x_lookup
    LDA square_x
    STA background_objects_x_lookup,X ; push square_x at the end of
                                      ; this range
    LDX background_objects_range_minus_one,Y ; get start index
    DEX                                      ; loop fudge
L173D
    INX                               ;next item
    CMP background_objects_x_lookup,X ;found square_x?
    BNE L173D                         ;branch taken if square_x not
                                      ;found
    TXA                               ;A = index of entry
    CMP background_objects_range,Y    ;is it the sentinel value?
    BCS no_background_object_in_hash  ;taken if so - i.e., no entry

; data_pointer = square_x + background_objects_data_offset

    ADC background_objects_data_offset,Y
    STA new_object_data_pointer

; type_pointer = X + background_objects_data_offset + background_objects_type_offset
    CLC
    ADC background_objects_type_offset,Y
    STA new_object_type_pointer

    LDA background_objects_handler_lookup,X
    JMP L1761 ; use_background_object_from_hash

no_background_object_in_hash
    LDX zp_various_9d ; background_object_number
    LDA lookup_for_unmatched_hash,X
    EOR square_orientation
;;  use_background_object_from_hash                                               ; A = handler_lookup if in hash, square_sprite if not
L1761
    STA square_sprite
    LDX background_objects_range,Y

; Undo sentinel.

    PLA
    STA background_objects_x_lookup,X

; Separate out orientation and sprite.

    LDA square_sprite
    AND #$C0
    STA square_orientation
    EOR square_sprite

no_background_object
    STA square_sprite
    RTS
;;  First, determine whether we should use mapped data or not
calculate_background
    LDA square_y
    TAX
    LSR @
    EOR square_x
    AND #$F8
    LSR @
    ADC square_x
    LSR @
    ADC square_y
    STA zp_various_9d    ; f_xy is a function of square_x and square_y
    TXA                  ; A = square_y
    CMP #$79
    BCC L17A8                   ; taken if square_y<0x79
    CMP #$BF
    BCC not_mapped2             ; taken if square_y<0xbf

; before: square_y = 0xc0 ... 0xff
; after:  square_y = 0x7a ... 0xb9

    SBC #$46 ; y >= $c0 ; y -= $46;

L17A8
; A = square_y
    CMP #$48
    BCS L17B2                   ; taken if square_y>=0x48
    CMP #$3E
    BCS not_mapped2             ; taken if square_y>=0x3e

; before: square_y = 0x00 ... 0x3d
; after:  square_y = 0x0a ... 0x47

    ADC #$0A

L17B2
    STA f2_xy                  ; at this point, a function of square_y
    AND #%10101000
    EOR #%01101111
    LSR @
    ADC square_x
    EOR #%01100000
    ADC #%00101000
    STA f3_xy     ; f3_xy is another function of square_x and square_y
    AND #%00111000
    EOR #%10100100
    ADC f2_xy
    STA f2_xy              ; f2_xy a function of square_x and square_y
    TAY                    ; A is f2_xy
    EOR #%00101100
    ADC f3_xy                   ; A is a function of f2_xy and f3_xy
    CPY #$20
    BCS not_mapped2             ; taken if f2_xy>=0x20
    CMP #$20
    BCS not_mapped              ; if A >= $20, don't use mapped data
    DEC square_is_mapped_data
    TAY                         ; Y = A = f(f2_xy,f3_xy)
    ASL @
    ASL @
    ASL @
    EOR f2_xy
    STA map_address             ; $a4 = (A * 8) ^ $10;
    TYA                         ; A = Y = f(f2_xy,f3_xy)
    AND #$03
    ADC #>(map_data)
    STA map_address_high        ; a5 = (A $ 3) + $4f;
    LDY #<(map_data)           ; $EC ; $4fec - $53ec
    LDA (map_address),Y         ; use mapped data
    RTS
L17EC
    JMP L1937
via_return_background_empty
    JMP return_background_empty

;  If not mapped data, are we on or above the surface?
;
not_mapped
; A =
    CMP #$3D
    BCC via_return_background_empty
not_mapped2
    CPX #$4E ; if square_y < $4e, return empty space
    BCC via_return_background_empty
    BEQ L17EC ; if square_y = $4e, return bushes
    CPX #$4F
    BNE below_surface
    LDA square_x                ; if square_y = $4f, do surface
    CMP #$40
    BEQ return_background_grass_frond ; force ($40, $4f) to be a grass frond
    LDY #$01
    JMP via_background_is_114f_lookup_with_y        ; otherwise, return wall
return_background_grass_frond
    LDA #$62 ; $62 = grass frond
    RTS
;;  Things get rather hairy below the surface...
below_surface
    LDY zp_various_9d ; f_xy
    LDA #$00
    STA zp_various_9d
    LDA square_x
    BIT square_y
    BMI L1821
    ADC #$1D
    CMP #$5E
    JMP L1825
L1821
    ADC #$07
    CMP #$2B
L1825
    BCC L187C
    TYA
    AND #$E8
    CMP square_y
    BCC L187C
    STY zp_various_9d
    TXA
    ASL @
    ADC square_y
    LSR @
    ADC square_y
    AND #$E0
    ADC square_x
    AND #$E8
    BNE no_mushrooms
    LDA square_y
    BPL via_return_background_empty                     ; no mushrooms if square_y < $80
    LDA square_x
    LSR @
    LSR @
    LSR @
    TAX
return_background_mushrooms
    LDA #$0E ; $0e = mushrooms (on floor)
    CPX #$0A
    BNE L1851
    LDA #$8E ; $8e = mushrooms (on ceiling)
L1851
    RTS
no_mushrooms
    TYA ; Y = f_xy
    LSR @
    LSR @
    AND #$30
    LSR @
    ADC square_x
    LSR @
    EOR square_x
    LSR @
    EOR square_x
    ADC square_x
    AND #$FD
    EOR square_x
    AND #$07
    BNE L1878
    LDA square_x
    BMI L1875
    LSR @
    ADC square_y
    AND #$30
    BEQ L1878
L1875
    LDA #$08 ; return hash point 8
    RTS
L1878
    CPX #$52
    BCS L187F
L187C
    JMP background_is_114f_lookup_with_top_of_9d
L187F
    TYA
    AND #$68
    ADC square_y
    LSR @
    ADC square_y
    LSR @
    ADC square_y
    AND #$FC
    EOR square_y
    AND #$17
    BNE L18DF
    TYA
    ADC square_x
    AND #$50
    BEQ return_background_empty
    AND square_x
    LSR @
    LSR @
    ADC square_y
    LSR @
    LSR @
    AND #$0F
    CMP #$08
    BCC L18AF
    BIT zp_various_9d
    BVC L18C1
    ORA #$04
    BNE L18C1
L18AF
    STA zp_various_9c
    EOR #$05
    CMP #$06
    LDA zp_various_9c
    BCS L18C1
    TYA
    LSR @
    ADC square_y
    EOR square_x
    AND #$07
L18C1
    CLC
    ADC #$1D
    PHA
    JSR some_background_calc_thing
    PLA
    BCC return_background_empty
    TAY
    LDA background_lookup,Y
    LDY square_y
    CPY #$E0
    BNE L18D7
    EOR #$40
L18D7
    RTS
return_background_empty
    LDY #$00
background_is_114f_lookup_with_y
    SEC
    LDA background_lookup,Y
    RTS
L18DF
    JSR some_background_calc_thing
    BCS background_is_114f_lookup_with_top_of_9d
    CPY #$00
    BEQ background_is_114f_lookup_with_y                ; empty space
    LDA zp_various_9d
    PHA
    STY zp_various_9c
    ROL @
    ROL @
    ROL @
    AND #$01
    ROL @
    TAY
    PLA
    ADC square_x
    ROL @
    EOR square_y
    AND #$1A
    BNE L1913
    TYA
    LDY zp_various_9c
    EOR background_lookup+7,Y
    AND #$7F
    CMP #$40
    ROL @
    AND #$07
    TAX
    LDA background_lookup+17,X
    EOR background_lookup+7,Y
    RTS
L1913
    LDA background_lookup+13,Y
    LDY zp_various_9c
    EOR background_lookup+7,Y
    RTS
background_is_114f_lookup_with_top_of_9d
    LDA zp_various_9d
    LSR @
    LSR @
    LSR @
    AND #$0E
    LSR @
    ADC #$01
    TAY
via_background_is_114f_lookup_with_y
    JMP background_is_114f_lookup_with_y
L192A
    ADC square_x
    ROL @
    ROL @
    ROL @
    AND #$02
    ADC #$19
    TAY
    JMP background_is_114f_lookup_with_y
L1937
    LDY #$19
    LDA square_x
    LSR @
    ADC square_x
    AND #$17
    BNE L192A
    ROR zp_various_9d
    ROR @
    RTS
some_background_calc_thing
    TXA
    LSR @
    EOR square_y
    AND #$06
    BNE L1971
    TYA
    LDY #$02
    AND #$20
    ASL @
    ASL @
    EOR #$E5
    STA L1961 ; self modifying code
    BMI L195E
    LDY #$04
L195E
    TXA
    ADC #$16
L1961
    ADC square_x
    AND #$5F
    TAX
    DEX
    CPX #$0C
    BCC L19A3
    BEQ L19A5
    INY
    INX
    BEQ L19A5
L1971
    LDA square_x
    LSR @
    LSR @
    LSR @
    LSR @
    BCS L19A2
    LDA #$01
    ADC square_x
    ADC square_y
    AND #$8F
    CMP #$01
    BEQ L19A3
    TAX
    SEC
    LDA square_y
    SBC square_x
    AND #$2F
    CMP #$01
    BEQ L19A3
    LDY #$02
    CMP #$02
    BEQ L19A5
    INY
    BCC L19A5
    INY
    CPX #$02
    BEQ L19A5
    INY
    BCC L19A5
L19A2
    RTS
L19A3
    LDY #$00
L19A5
    CLC
L19A6
; Convert a selected map tile into the sprite attributes used by the plotter.
setup_background_sprite_values_from_08_09
    TAY                             ; Y = square_sprite
    LDA background_palette_lookup,Y ; what's the palette for this
                                    ; sprite?
    BNE palette_not_zero            ; palette_defined

; objects with zero palette, coloured according to Y coordinate:
;
; 05 = brick wall, 3/4 full, \, filled in bottom left
; 13 = brick wall, \, starting top middle, ending middle right, 3/4 full
; 1e = brick wall, solid
; 1f = brick wall, bottom half
; 20 = horizontal brick door
; 23 = brick \ wall, filled in bottom left
; 24 = brick wall, \, starting top left, ending middle right
; 25 = brick wall, \, starting middle left, ending bottom right
; 2a = brick wall, \, very steep down
; 3a = gargoyle, bottom left
; 3b = brick wall, 3/4 filled bottom
;
; get their palette from wall_palette_lookup[(square_y-$54)/16]

    LDA square_y                ;
    SEC                         ;
    SBC #$54                    ; square_y-$54
    LSR @                       ; /2
    LSR @                       ; /4
    LSR @                       ; /8
    LSR @                       ; /16
    TAX                         ;
    LDA wall_palette_zero_lookup,X ; array lookup

palette_not_zero
    CMP #$03
    BCS palette_not_two      ; taken if >=3

; palette is 1 or 2 - function of square_y<0x80
;
; square_y<0x80?0xb1+palette:(0xb1+palette)<<1+0x91

    ADC #$B1                    ; palette is $B2 (1) or $B3 (2)
    BIT square_y                ;
    BPL palette_not_six         ; taken if square_y<0x80

; square_y>=0x80

    ASL @                       ; palette is $64 (1) or $66 (2), and C
                                ; set
    ADC #$90                    ; palette is $f5 (1) or $f7 (2)

palette_not_two
    CMP #$03
    BNE palette_not_three

; palette is 3 - function of x, y and orientation

    LDA square_orientation      ; C=1 %ab000000
    ROL @                       ; C=a %b0000001
    ROL @                       ; C=b %0000001a
    ROL @                       ; C=0 %000001ab
    SBC square_y                ; um
    ROR @                       ; ...
    CLC                         ; ???
    ADC square_x                ; ...
    AND #$03                    ; it's only 2 bits though
    TAX                         ;
    LDA wall_palette_three_lookup,X ;
palette_not_three
    CMP #$04
    BNE palette_not_four

; palette is 4 - it's wall_palette_four_lookup[square_y>>4$7]

    LDA square_y
    ROL @
    ROL @
    ROL @
    ROL @
    AND #$07
    TAX
    LDA wall_palette_four_lookup,X
palette_not_four
    CMP #$05
    BNE palette_not_five

; palette is 5 - a function of y and orientation

    LDA square_y
    ROR @
    ROR @
    EOR square_y
    ROR @
    BCC L23EF
    LDY #$19
L23EF
    ROR @
    SBC square_y
    AND #$40
    EOR square_orientation
    BIT square_orientation
    STA square_orientation
    LDA #$B1
    BVC palette_not_six
    ADC #$0A
palette_not_five
    CMP #$06
    BNE palette_not_six

; palette is 6 - a function of orientation

    LDA #$9C
    BIT square_orientation
    BVC palette_not_six
    LDA #$CF
palette_not_six
    STA this_object_palette     ; set the palette for this square
    STA this_object_palette_old
    LDA square_orientation
    STA this_object_flipping_flags ; set the orientation for this square
    STA this_object_flipping_flags_old

; Translate background sprite to object sprite.

    LDA background_sprite_lookup,Y
    AND #$7F                       ; mask off the extra flag
    TAX
    STA this_object_sprite
    STA this_object_sprite_old

; Adjust Y coordinate.

    LDA background_y_offset_lookup,Y ; Y = background sprite
    AND #$F0                         ; %11110000
    BIT square_orientation
    BVC L2430                        ; taken if not flipped vertically
    ADC sprite_height_lookup,X       ; adjust Y to account for flip
    ORA #$07                         ; (the lower bits of
                                     ; sprite_height_lookup are used
                                     ; for something)
    EOR #$FF                         ; negate???
L2430
    STA this_object_y_low       ; y position of start of square sprite
    STA this_object_y_low_old
    LDA #$00
    BIT square_orientation
    BPL L243F                   ; taken if not flipped horizontally
    LDA #$F2                    ; %11110010
    SBC sprite_width_lookup,X   ;
L243F
    STA this_object_x_low
    STA this_object_x_low_old   ; x position of start of square sprite
    LDA square_x
    STA this_object_x
    STA this_object_x_old
    LDA square_y
    STA this_object_y
    STA this_object_y_old
    RTS

;;  A determines X on leaving

; The original world map and sprite geometry tables used by the native renderer.
map_data
    dta $95,$B6,$19,$EF,$6F,$6E,$70,$5E,$D4,$A9,$A9,$57,$6D,$06,$6E,$ED
    dta $2D,$6E,$6E,$06,$CA,$70,$AD,$07,$5E,$5E,$53,$62,$53,$9B,$35,$9E
    dta $15,$16,$E9,$22,$57,$97,$0C,$CC,$8C,$78,$3F,$BD,$05,$ED,$E2,$0A
    dta $F0,$05,$2D,$6E,$D3,$07,$E4,$24,$63,$A1,$A5,$64,$53,$07,$A4,$63
    dta $66,$7E,$3E,$DC,$8C,$72,$E8,$BC,$06,$19,$22,$6D,$DE,$D3,$19,$71
    dta $F1,$7E,$29,$F4,$39,$A9,$D3,$06,$53,$A1,$E4,$07,$D4,$A9,$D3,$1A
    dta $C1,$77,$D7,$41,$6F,$A1,$6D,$53,$F5,$D3,$21,$19,$A1,$53,$06,$E5
    dta $EE,$19,$97,$D3,$13,$EA,$75,$02,$D3,$9B,$53,$EA,$5F,$85,$72,$21
    dta $6E,$2C,$2D,$07,$AD,$ED,$B1,$25,$19,$2F,$53,$3B,$9E,$E2,$D3,$62
    dta $02,$F0,$2D,$06,$A4,$D3,$19,$21,$53,$21,$ED,$30,$D3,$6A,$59,$A4
    dta $6D,$70,$6F,$04,$A4,$64,$A2,$A2,$1E,$04,$D3,$01,$4A,$3B,$64,$63
    dta $F0,$2D,$17,$ED,$F4,$2F,$12,$30,$D3,$21,$FA,$A2,$A1,$E2,$8D,$2E
    dta $64,$6E,$02,$EE,$04,$05,$13,$EE,$4A,$6A,$2D,$05,$9B,$2D,$25,$65
    dta $ED,$FE,$31,$6F,$F0,$14,$EE,$BF,$DF,$8D,$D3,$6A,$DE,$53,$8B,$1E
    dta $EE,$AD,$70,$7A,$24,$A1,$22,$6D,$22,$D3,$21,$93,$DF,$01,$02,$DC
    dta $AE,$7C,$06,$AF,$DF,$B2,$07,$29,$03,$5E,$CD,$EA,$53,$CD,$07,$8F
    dta $FC,$94,$66,$69,$30,$07,$62,$35,$D6,$9D,$BF,$2F,$9D,$62,$62,$1F
    dta $53,$21,$D3,$43,$FE,$45,$93,$74,$9E,$F0,$91,$AE,$A1,$62,$02,$07
    dta $6A,$CC,$D9,$3D,$E2,$ED,$ED,$B0,$B4,$15,$E6,$19,$57,$17,$9D,$4C
    dta $ED,$A2,$93,$65,$03,$21,$9E,$05,$B4,$B0,$06,$EE,$5E,$A1,$5E,$25
    dta $49,$F9,$07,$7C,$DE,$DE,$EA,$07,$67,$04,$BD,$68,$53,$CC,$26,$A8
    dta $7A,$21,$DE,$E2,$9E,$06,$53,$A1,$1E,$E2,$04,$E8,$9E,$04,$64,$06
    dta $B9,$06,$DA,$13,$E3,$4A,$21,$F8,$05,$C2,$32,$97,$07,$62,$ED,$70
    dta $EF,$EA,$D3,$6A,$E4,$19,$C6,$F3,$03,$19,$A8,$1E,$28,$9E,$F5,$29
    dta $07,$04,$70,$21,$1E,$1E,$06,$FA,$EE,$2C,$2D,$F0,$13,$53,$BB,$F0
    dta $56,$21,$ED,$A1,$AA,$C0,$C4,$53,$62,$EF,$2F,$F0,$70,$5E,$A1,$19
    dta $6F,$DE,$1E,$A1,$24,$02,$5F,$62,$6D,$06,$71,$8D,$13,$71,$B0,$AF
    dta $56,$EA,$DE,$A5,$21,$E5,$4B,$8D,$03,$2F,$29,$2D,$57,$38,$6E,$07
    dta $D3,$19,$2A,$E3,$B5,$6E,$49,$E5,$70,$62,$B0,$12,$53,$D3,$22,$6D
    dta $DF,$8D,$53,$A1,$D4,$DF,$21,$1E,$2D,$F0,$22,$70,$6E,$35,$12,$E2
    dta $9A,$23,$A1,$61,$68,$05,$A5,$D3,$04,$2E,$06,$19,$07,$D3,$E1,$2E
    dta $24,$9B,$53,$CD,$07,$CD,$CA,$0F,$52,$ED,$E2,$2E,$05,$34,$78,$04
    dta $3A,$7B,$04,$AD,$53,$E1,$B1,$07,$DF,$21,$13,$FA,$7E,$19,$5E,$7B
    dta $05,$96,$3F,$BD,$54,$DD,$19,$B1,$32,$BC,$69,$2B,$21,$6F,$EE,$19
    dta $B8,$B2,$2D,$2D,$64,$20,$53,$03,$53,$A1,$3E,$FE,$D3,$07,$53,$FB
    dta $A8,$B7,$29,$2B,$E8,$BC,$68,$DD,$19,$39,$A2,$B1,$F0,$53,$1E,$AD
    dta $70,$3B,$03,$D6,$53,$1E,$7A,$A5,$07,$1B,$53,$DE,$1E,$9E,$D3,$21
    dta $D6,$19,$68,$FD,$02,$6A,$34,$66,$B0,$9E,$04,$EF,$04,$DE,$ED,$F1
    dta $ED,$18,$A4,$69,$17,$53,$53,$E2,$ED,$30,$DE,$EA,$9E,$19,$19,$47
    dta $EF,$06,$8C,$72,$EF,$19,$2F,$F0,$ED,$B9,$99,$B1,$DE,$23,$A3,$78
    dta $A2,$2F,$30,$EF,$04,$B5,$E4,$A1,$D3,$19,$7A,$A1,$CD,$DA,$1B,$D3
    dta $6D,$06,$ED,$71,$B1,$6E,$04,$6D,$EE,$AF,$4A,$D1,$5E,$1E,$53,$7C
    dta $EF,$18,$F0,$2D,$02,$B8,$7F,$62,$7C,$8D,$12,$DE,$C6,$E4,$8B,$AE
    dta $0D,$ED,$AD,$8D,$E2,$DF,$B1,$6E,$E4,$04,$64,$07,$25,$F0,$E4,$19
    dta $2E,$EF,$19,$B0,$4F,$32,$75,$07,$E4,$8D,$5F,$21,$D4,$CD,$CB,$53
    dta $8F,$AE,$AF,$ED,$4A,$21,$A1,$79,$23,$EA,$07,$13,$54,$F5,$62,$24
    dta $6F,$4A,$EE,$11,$13,$93,$1E,$A9,$25,$5F,$A1,$7A,$24,$A5,$5E,$0F
    dta $A4,$1E,$EE,$19,$A0,$53,$E1,$A1,$93,$93,$D3,$E1,$32,$97,$93,$53
    dta $D3,$19,$21,$1E,$F9,$19,$A5,$03,$6B,$21,$AE,$12,$7C,$6A,$FA,$2D
    dta $38,$72,$BF,$B0,$21,$EF,$11,$B5,$56,$36,$02,$3D,$68,$01,$8C,$30
    dta $D3,$21,$64,$7E,$64,$A1,$7C,$21,$54,$FE,$F2,$6E,$E4,$29,$5F,$04
    dta $19,$19,$2A,$AF,$2D,$E2,$6A,$6F,$A7,$69,$F7,$E9,$32,$A8,$FC,$28
    dta $FA,$07,$D3,$6A,$64,$32,$53,$05,$4A,$62,$04,$56,$D3,$6A,$54,$A4
    dta $6D,$53,$E2,$ED,$69,$14,$1E,$EF,$37,$00,$40,$28,$D3,$05,$2D,$74
    dta $ED,$05,$EF,$5E,$53,$E3,$19,$A5,$30,$05,$17,$A1,$A8,$5F,$21,$05
    dta $22,$ED,$E2,$B1,$62,$02,$64,$65,$6D,$2C,$12,$CC,$6D,$E2,$04,$D3
    dta $53,$A1,$19,$AB,$A2,$CD,$8B,$13,$01,$AF,$21,$ED,$51,$94,$F5,$29
    dta $39,$2E,$F0,$1A,$5E,$02,$1E,$7A,$AD,$ED,$39,$70,$B1,$EE,$03,$B4
    dta $D6,$8D,$53,$21,$C2,$DE,$8B,$2D,$ED,$19,$2F,$2F,$01,$AF,$FF,$3F
    dta $53,$00,$ED,$25,$06,$EF,$24,$E2,$2D,$ED,$ED,$DE,$5E,$7B,$31,$07
    dta $13,$CD,$D3,$1B,$D4,$CD,$07,$06,$A2,$6F,$A2,$31,$F0,$06,$F8,$62
    dta $A1,$53,$AA,$00,$64,$05,$00,$25,$0F,$6D,$53,$ED,$D3,$19,$13,$93
    dta $22,$D3,$22,$E1,$05,$64,$65,$2D,$70,$19,$62,$06,$22,$63,$63,$BB
    dta $64,$63,$53,$04,$22,$72,$63,$7E,$64,$63,$64,$05,$22,$65,$5B,$A1

;; ##############################################################################
;;
;;    Sprites
;;    =======
;;    $00 spaceman, flying horizontally
;;    $01 spaceman, reclined forwards
;;    $02 spaceman, upright, jumping
;;    $03 spaceman, reclined backwards
;;    $04 spaceman, upright, stationary
;;    $05 spaceman, upright, walking
;;    $06 spaceman, upright, walking
;;    $07 spaceman, upright, walking
;;    $08 bullet
;;    $09 bullet
;;    $0a bullet
;;    $0b bullet
;;    $0c bullet
;;    $0d bullet
;;    $0e grass frond
;;    $0f red drop
;;    $10 frogman
;;    $11 frogman
;;    $12 frogman
;;    $13 robot
;;    $14 chatter
;;    $15 hovering robot
;;    $16 clawed robot
;;    $17 fireball
;;    $18 grass tuft
;;    $19 half bush
;;    $1a bush
;;    $1b full nest
;;    $1c half nest / slime
;;    $1d half nest / slime
;;    $1e small round nest / slime
;;    $1f small nest / slime
;;    $20 rock
;;    $21 plasma ball
;;    $22 coronium crystal
;;    $23 spaceship support
;;    $24 spaceship corner with pipes
;;    $25 spaceship tiny corner
;;    $26 spaceship wall left quarter
;;    $27 spaceship wall \ from top left to top 3/4 right
;;    $28 spaceship wall \ from top 3/4 left to middle right
;;    $29 spaceship wall \ from middle left to 1/4 right
;;    $2a spaceship wall \ from 1/4 right to bottom left
;;    $2b spaceship corner
;;    $2c spaceship wall bottom half
;;    $2d switch box
;;    $2e switch
;;    $2f pipe corner, bottom left
;;    $30 pipe left side, with top corner
;;    $31 pipe bottom side, with right corner
;;    $32 spaceship wall bottom half with pipework and pipe
;;    $33 spaceship corner with pipes
;;    $34 brick wall \ from top left to middle right
;;    $35 brick wall \ from middle left to bottom right
;;    $36 stone wall \ from top left to middle right
;;    $37 stone wall \ from middle left to bottom right
;;    $38 stone wall \, filled bottom left
;;    $39 brick wall, full
;;    $3a brick wall, bottom three quarters
;;    $3b brick wall, bottom half
;;    $3c brick wall, bottom quarter
;;    $3d stone wall, full
;;    $3e stone wall, bottom half with edging
;;    $3f very thin edge, bottom
;;    $40 stone wall, bottom half with edging
;;    $41 brick wall, left quarter
;;    $42 brick wall, left quarter, steep slope
;;    $43 brick wall, \, filled bottom left
;;    $44 brick wall, \, filled bottom left 3/4s
;;    $45 gargoyle
;;    $46 brick wall, bottom quarter
;;    $47 spaceship wall with pipework
;;    $48 spaceship wall, bottom half
;;    $49 spaceship wall, bottom quarter
;;    $4a horizontal door
;;    $4b vertical door
;;    $4c hydraulic leg
;;    $4d key
;;    $4e teleporter
;;    $4f wasp
;;    $50 wasp
;;    $51 wasp
;;    $52 maggot
;;    $53 maggot
;;    $54 maggot
;;    $55 pillar
;;    $56 cannon
;;    $57 mysterious weapon
;;    $58 rcd
;;    $59 bird
;;    $5a bird
;;    $5b bird
;;    $5c bird
;;    $5d chest
;;    $5e turret
;;    $5f flagpole
;;    $60 destinator
;;    $61 big fish
;;    $62 mushrooms
;;    $63 mushroom ball
;;    $64 imp
;;    $65 imp
;;    $66 imp
;;    $67 imp
;;    $68 imp
;;    $69 imp
;;    $6a large pipe top
;;    $6b jetpack booster
;;    $6c plasma gun
;;    $6d quarter lightning
;;    $6e half lightning
;;    $6f lightning
;;    $70 sucker
;;    $71 teleporter beam
;;    $72 pirahna
;;    $73 pirahna
;;    $74 pirahna
;;    $75 fluffy
;;    $76 flask
;;    $77 (nothing)
;;    $78 hoverball
;;    $79 pill
;;    $7a fire immunity device
;;    $7b energy capsule
;;    $7c whistle
;;
;;    Sprite data is 128 x 128, 20 bytes per row.
;;
;; ##############################################################################
;; 6000 - 7fff is used as screen memory



sprite_width_lookup

; %wwww000h
;
; 1+%wwww is the sprite width in pixels
;
; if h=1, the horizontal flip flag is inverted when plotting the
; sprite

;        0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    dta $C0,$A0,$50,$90,$40,$50,$60,$40,$21,$20,$20,$21,$11,$11,$50,$30 ; 0
    dta $60,$51,$50,$50,$80,$50,$50,$B0,$B0,$80,$80,$50,$90,$70,$50,$30 ; 1
    dta $40,$20,$10,$F1,$F1,$71,$30,$F0,$F0,$F0,$F0,$F1,$F0,$30,$60,$30 ; 2
    dta $30,$F0,$F0,$F1,$F0,$F0,$F0,$F0,$F1,$F0,$F0,$F0,$F0,$F0,$F0,$F0 ; 3
    dta $F0,$30,$60,$F0,$F0,$70,$00,$F0,$F0,$F0,$F0,$30,$31,$41,$F0,$20 ; 4
    dta $40,$20,$50,$50,$30,$70,$C0,$40,$40,$20,$60,$60,$40,$F0,$70,$20 ; 5
    dta $70,$90,$C0,$30,$40,$50,$60,$40,$40,$30,$F0,$20,$30,$31,$70,$B1 ; 6
    dta $F0,$70,$51,$41,$50,$51,$30,$80,$30,$30,$50,$50,$40 ;             7

sprite_height_lookup
; %hhhhh00v
;
; 1+%hhhhh is the sprite height in pixels
;
; if v=1, the vertical flip flag is inverted when plotting the sprite

;        0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    dta $40,$80,$98,$91,$A8,$A0,$A0,$A0,$09,$08,$10,$19,$19,$18,$58,$18 ; 0
    dta $60,$78,$81,$98,$78,$70,$98,$90,$28,$48,$78,$69,$20,$28,$38,$48 ; 1
    dta $38,$20,$08,$F8,$F8,$68,$F9,$F9,$B9,$79,$39,$F8,$78,$38,$38,$38 ; 2
    dta $F8,$38,$78,$F8,$F8,$78,$F8,$78,$F8,$F8,$C9,$78,$38,$F8,$89,$09 ; 3
    dta $49,$F8,$F8,$F9,$F9,$68,$00,$F8,$78,$38,$39,$F9,$F9,$28,$48,$18 ; 4
    dta $11,$19,$20,$29,$41,$F8,$70,$30,$20,$20,$19,$18,$28,$60,$48,$80 ; 5
    dta $58,$58,$39,$19,$68,$68,$68,$58,$68,$58,$38,$38,$28,$48,$48,$48 ; 6
    dta $48,$08,$30,$20,$28,$39,$70,$38,$30,$20,$20,$20,$20 ;             7

sprite_offset_a_lookup
;        0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    dta $36,$44,$C5,$04,$66,$06,$91,$41,$60,$43,$D0,$D4,$E4,$E4,$A4,$03 ; 0
    dta $97,$63,$03,$05,$77,$97,$65,$06,$06,$06,$06,$E6,$C6,$D6,$E6,$F6 ; 1
    dta $37,$D6,$65,$02,$03,$12,$C2,$03,$03,$03,$03,$02,$02,$04,$96,$C4 ; 2
    dta $04,$04,$43,$43,$00,$00,$05,$05,$01,$00,$00,$00,$00,$05,$05,$05 ; 3
    dta $05,$00,$C0,$00,$00,$44,$C0,$03,$03,$03,$07,$07,$53,$17,$02,$D4 ; 4
    dta $80,$D4,$07,$F6,$C6,$87,$04,$84,$47,$67,$C6,$C6,$96,$02,$44,$D4 ; 5
    dta $C3,$67,$36,$86,$01,$51,$31,$B1,$B1,$C4,$02,$67,$47,$15,$55,$35 ; 6
    dta $05,$00,$16,$37,$E6,$76,$04,$B6,$C4,$47,$84,$B6,$A4 ;             7

sprite_offset_b_lookup
;        0   1   2   3   4   5   6   7   8   9   a   b   c   d   e   f
    dta $42,$02,$E9,$81,$98,$98,$E0,$E0,$7A,$00,$72,$E1,$5A,$3A,$81,$00 ; 0
    dta $E1,$0A,$02,$E9,$60,$68,$E9,$00,$00,$49,$49,$50,$68,$68,$58,$50 ; 1
    dta $D0,$D9,$A0,$00,$28,$01,$01,$09,$49,$89,$C9,$01,$81,$41,$81,$41 ; 2
    dta $80,$41,$80,$20,$00,$00,$00,$00,$89,$80,$80,$80,$31,$80,$09,$89 ; 3
    dta $49,$80,$80,$71,$01,$D0,$00,$80,$01,$41,$4A,$89,$A8,$E9,$F9,$C0 ; 4
    dta $72,$C0,$00,$20,$00,$E0,$00,$18,$11,$E1,$C0,$C8,$51,$B1,$78,$00 ; 5
    dta $2A,$00,$02,$02,$00,$00,$70,$00,$60,$E0,$4A,$0A,$B1,$99,$99,$99 ; 6
    dta $99,$72,$C9,$61,$59,$C1,$D0,$11,$88,$89,$90,$E8,$90 ;             7

	; DLI, display list, camera ring, and incremental dirty-cell engine.
	org $80A0

m4_dli
    ; Keep DLI register saves out of page 1, which also contains code.
    STA m4_dli_saved_a
    TXA
    STA m4_dli_saved_x
    LDX m4_dli_index
    LDA m4_charset_pages,X
        sta $d40a ;wsync
    STA CHBASE
    inc m4_dli_index
    LDX m4_dli_saved_x
    LDA m4_dli_saved_a
    RTI

m4_charset_pages
:24   dta h(vramfont+[[#>>2]%6]*$400)
m4_font_bank_pages
:6    dta h(vramfont+#*$400)

vramfont	equ $e000

m4_dli_index
    dta 1
m4_dli_saved_a
    dta 0
m4_dli_saved_x
    dta 0

	.align $100                 ; display list

m4_dl
    dta $70,$70
GAME_LMS_DL_NORMAL=$44
GAME_LMS_DL_DLI=$C4
    :23 dta GAME_LMS_DL_DLI,a(m4_game_scroll_map+[#*64])
    dta GAME_LMS_DL_NORMAL,a(m4_game_scroll_map+23*64)
    dta $70
    dta $41,a(m4_dl)

    .align $100

; 64-code ring rows let each LMS address select a 32-cell window with margin.
m4_game_scroll_map
    :27*64 dta [[[#/64]&3]*32]+[#&31]
m4_game_scroll_x
    dta 0
m4_game_scroll_y
    dta 0
m4_game_scroll_abs_x
    dta 0
m4_game_scroll_abs_y
    dta 0
m4_game_scroll_band_base
    dta 0
m4_game_charset_bank_tmp
    dta 0
m4_game_charset_row_tmp
    dta 0
M4_GAME_LMS_SRC=$A6
M4_GAME_LMS_DST=$A8

m4_game_scroll_prepare
    LDA screen_start_square_x
    ASL
    ASL
    AND #$1C
    STA m4_game_scroll_x
    LDA screen_start_square_x_low
    LSR
    LSR
    LSR
    LSR
    LSR
    LSR
    AND #$03
    ORA m4_game_scroll_x
    STA m4_game_scroll_x
    LDA screen_start_square_y_low
    LSR
    LSR
    LSR
    LSR
    LSR
    LSR
    AND #$03
    STA m4_game_scroll_y
    LDA screen_start_square_x
    ASL
    ASL
    STA m4_game_scroll_abs_x
    LDA screen_start_square_x_low
    LSR
    LSR
    LSR
    LSR
    LSR
    LSR
    AND #$03
    CLC
    ADC m4_game_scroll_abs_x
    STA m4_game_scroll_abs_x
    LDA screen_start_square_y
    ASL
    ASL
    STA m4_game_scroll_abs_y
    LDA screen_start_square_y_low
    LSR
    LSR
    LSR
    LSR
    LSR
    LSR
    AND #$03
    CLC
    ADC m4_game_scroll_abs_y
    STA m4_game_scroll_abs_y
m4_game_scroll_band_mod
    LDA screen_start_square_y
    STA m4_game_scroll_band_tmp
m4_game_scroll_band_mod_loop
    LDA m4_game_scroll_band_tmp
    CMP #6
    BCC m4_game_scroll_band_ready
    SEC
    SBC #6
    STA m4_game_scroll_band_tmp
    JMP m4_game_scroll_band_mod_loop
m4_game_scroll_band_ready
    STA m4_game_scroll_band_base
    RTS

m4_game_scroll_band_tmp
    dta 0

m4_incremental_initialized
    dta 0
m4_incremental_full_frame
    dta 0
m4_incremental_prev_x
    dta 0
m4_incremental_prev_y
    dta 0
m4_incremental_dx
    dta 0
m4_incremental_dy
    dta 0
m4_incremental_clip
    dta 0
; One dirty bit per visible character cell (24 rows x 32 columns).
m4_incremental_work
    :96 dta 0
m4_incremental_cell_row
    dta 0
m4_incremental_cell_col
    dta 0
m4_incremental_edge_col
    dta 0
m4_incremental_edge_row
    dta 0
m4_incremental_probe_line
    dta 0
m4_incremental_probe_row
    dta 0
m4_incremental_probe_col
    dta 0
m4_incremental_dirty_byte
    dta 0
m4_incremental_dirty_mask
    dta 0
m4_incremental_row_tmp
    dta 0
m4_incremental_col_tmp
    dta 0
m4_incremental_bank_tmp
    dta 0
m4_incremental_clear_byte
    dta 0
m4_incremental_clear_bits
    dta 0
m4_incremental_clear_bit
    dta 0
m4_incremental_clear_col
    dta 0
m4_incremental_bit_masks
    dta 1,2,4,8,16,32,64,128

m4_incremental_prepare
    LDX #95
m4_incremental_clear_work_map
    LDA #0
    STA m4_incremental_work,X
    DEX
    BPL m4_incremental_clear_work_map
    LDA #0
    STA m4_incremental_full_frame
    STA m4_incremental_dx
    STA m4_incremental_dy
    LDA m4_incremental_initialized
    BNE m4_incremental_check_x
    LDA #1
    STA m4_incremental_initialized
    STA m4_incremental_full_frame
    JMP m4_incremental_save_position
m4_incremental_check_x
    LDA m4_game_scroll_abs_x
    SEC
    SBC m4_incremental_prev_x
    BEQ m4_incremental_check_y
    CMP #1
    BEQ m4_incremental_x_right
    CMP #$FF
    BEQ m4_incremental_x_left
    JMP m4_incremental_force_full
m4_incremental_x_right
    LDA #1
    STA m4_incremental_dx
    JMP m4_incremental_check_y
m4_incremental_x_left
    LDA #$FF
    STA m4_incremental_dx
m4_incremental_check_y
    LDA m4_game_scroll_abs_y
    SEC
    SBC m4_incremental_prev_y
    BEQ m4_incremental_add_edges
    CMP #1
    BEQ m4_incremental_y_down
    CMP #$FF
    BEQ m4_incremental_y_up
    JMP m4_incremental_force_full
m4_incremental_y_down
    LDA #1
    STA m4_incremental_dy
    JMP m4_incremental_add_edges
m4_incremental_y_up
    LDA #$FF
    STA m4_incremental_dy
m4_incremental_add_edges
    LDA m4_incremental_dx
    BEQ m4_incremental_add_y_edge
    CMP #1
    BEQ m4_incremental_right_edge
    LDA #0
    BEQ m4_incremental_set_x_edge
m4_incremental_right_edge
    LDA #31
m4_incremental_set_x_edge
    STA m4_incremental_edge_col
    LDA #0
    STA m4_incremental_cell_row
m4_incremental_x_edge_loop
    LDA m4_incremental_edge_col
    STA m4_incremental_cell_col
    JSR m4_incremental_mark_work_cell
    INC m4_incremental_cell_row
    LDA m4_incremental_cell_row
    CMP #24
    BNE m4_incremental_x_edge_loop
m4_incremental_add_y_edge
    LDA m4_incremental_dy
    BEQ m4_incremental_save_position
    CMP #1
    BEQ m4_incremental_bottom_edge
    LDA #0
    BEQ m4_incremental_set_y_edge
m4_incremental_bottom_edge
    LDA #23
m4_incremental_set_y_edge
    STA m4_incremental_edge_row
    LDA #0
    STA m4_incremental_cell_col
m4_incremental_y_edge_loop
    LDA m4_incremental_edge_row
    STA m4_incremental_cell_row
    JSR m4_incremental_mark_work_cell
    INC m4_incremental_cell_col
    LDA m4_incremental_cell_col
    CMP #32
    BNE m4_incremental_y_edge_loop
    JMP m4_incremental_save_position
m4_incremental_force_full
    LDA #1
    STA m4_incremental_full_frame
m4_incremental_save_position
    LDA m4_game_scroll_abs_x
    STA m4_incremental_prev_x
    LDA m4_game_scroll_abs_y
    STA m4_incremental_prev_y
    RTS

m4_incremental_mark_work_cell
    LDA m4_incremental_cell_row
    CLC
    ADC m4_game_scroll_y
    STA m4_incremental_row_tmp
    AND #3
    ASL
    ASL
    STA m4_incremental_dirty_byte
    LDA m4_incremental_row_tmp
    LSR
    LSR
    CLC
    ADC m4_game_scroll_band_base
    CMP #6
    BCC m4_incremental_bank_ready
    SEC
    SBC #6
m4_incremental_bank_ready
    ASL
    ASL
    ASL
    ASL
    CLC
    ADC m4_incremental_dirty_byte
    STA m4_incremental_dirty_byte
    LDA m4_incremental_cell_col
    CLC
    ADC m4_game_scroll_x
    AND #$1F
    STA m4_incremental_col_tmp
    LSR
    LSR
    LSR
    CLC
    ADC m4_incremental_dirty_byte
    STA m4_incremental_dirty_byte
    LDA m4_incremental_col_tmp
    AND #7
    TAX
    LDA m4_incremental_bit_masks,X
    STA m4_incremental_dirty_mask
    LDX m4_incremental_dirty_byte
    LDA m4_incremental_work,X
    ORA m4_incremental_dirty_mask
    STA m4_incremental_work,X
    RTS

m4_incremental_clear_dirty
    LDA #0
    STA m4_incremental_clear_byte
m4_incremental_clear_byte_loop
    LDX m4_incremental_clear_byte
    LDA m4_incremental_work,X
    STA m4_incremental_clear_bits
    BEQ m4_incremental_clear_next_byte
    LDA m4_incremental_clear_byte
    LSR
    LSR
    CLC
    ADC #>vramfont
    STA SPR_DST+1
    LDA m4_incremental_clear_byte
    AND #3
    ASL
    ASL
    ASL
    STA m4_incremental_clear_col
    LDA #0
    STA m4_incremental_clear_bit
m4_incremental_clear_bit_loop
    LDX m4_incremental_clear_bit
    LDA m4_incremental_bit_masks,X
    AND m4_incremental_clear_bits
    BEQ m4_incremental_clear_next_bit
    LDA m4_incremental_clear_col
    CLC
    ADC m4_incremental_clear_bit
    ASL
    ASL
    ASL
    STA SPR_DST
    LDY #0
    LDA #0
m4_incremental_clear_cell_loop
    STA (SPR_DST),Y
    INY
    CPY #8
    BNE m4_incremental_clear_cell_loop
m4_incremental_clear_next_bit
    INC m4_incremental_clear_bit
    LDA m4_incremental_clear_bit
    CMP #8
    BNE m4_incremental_clear_bit_loop
m4_incremental_clear_next_byte
    INC m4_incremental_clear_byte
    LDA m4_incremental_clear_byte
    CMP #96
    BNE m4_incremental_clear_byte_loop
    RTS

m4_game_lms_patch
    LDA #<m4_game_scroll_map
    STA M4_GAME_LMS_SRC
    LDA #>m4_game_scroll_map
    STA M4_GAME_LMS_SRC+1
    LDA m4_game_scroll_y
    ASL
    ASL
    ASL
    ASL
    ASL
    ASL
    CLC
    ADC M4_GAME_LMS_SRC
    STA M4_GAME_LMS_SRC
    LDA M4_GAME_LMS_SRC+1
    ADC #0
    STA M4_GAME_LMS_SRC+1
    CLC
    LDA M4_GAME_LMS_SRC
    ADC m4_game_scroll_x
    STA M4_GAME_LMS_SRC
    LDA M4_GAME_LMS_SRC+1
    ADC #0
    STA M4_GAME_LMS_SRC+1
    LDA #<(m4_dl+3)
    STA M4_GAME_LMS_DST
    LDA #>(m4_dl+3)
    STA M4_GAME_LMS_DST+1
    LDX #24
m4_game_lms_patch_row
    LDY #0
    LDA M4_GAME_LMS_SRC
    STA (M4_GAME_LMS_DST),Y
    INY
    LDA M4_GAME_LMS_SRC+1
    STA (M4_GAME_LMS_DST),Y
    LDA M4_GAME_LMS_SRC
    CLC
    ADC #64
    STA M4_GAME_LMS_SRC
    BCC m4_game_lms_src_no_carry
    INC M4_GAME_LMS_SRC+1
m4_game_lms_src_no_carry
    LDA M4_GAME_LMS_DST
    CLC
    ADC #3
    STA M4_GAME_LMS_DST
    BCC m4_game_lms_dst_no_carry
    INC M4_GAME_LMS_DST+1
m4_game_lms_dst_no_carry
    DEX
    BNE m4_game_lms_patch_row
    RTS

m4_game_charset_patch
    LDA m4_game_scroll_band_base
    STA m4_game_charset_bank_tmp
    LDA m4_game_scroll_y
    STA m4_game_charset_row_tmp
    LDY #0
m4_game_charset_patch_row
    LDA m4_game_charset_bank_tmp
    ASL
    ASL
    CLC
    ADC #>vramfont
    STA m4_charset_pages,Y
    INC m4_game_charset_row_tmp
    LDA m4_game_charset_row_tmp
    CMP #4
    BCC m4_game_charset_no_bank_advance
    LDA #0
    STA m4_game_charset_row_tmp
    INC m4_game_charset_bank_tmp
    LDA m4_game_charset_bank_tmp
    CMP #6
    BCC m4_game_charset_no_bank_advance
    LDA #0
    STA m4_game_charset_bank_tmp
m4_game_charset_no_bank_advance
    INY
    CPY #24
    BNE m4_game_charset_patch_row
    RTS

SPR_DST=$EC                     ; pointer into charsets (glyph byte)
SPR_COL=$EF                     ; screen column 0..31
SPR_Y=$F0                       ; screen line
SPR_T=$F8                       ; temp
SPR_ROW=$F9                     ; screen cell row

; Translate a screen cell through the active ring bank to its charset address.
glyph_addr
    LDA SPR_Y
    LSR
    LSR
    LSR
    STA SPR_ROW
    LDA SPR_ROW
    CLC
    ADC m4_game_scroll_y
    STA m4_incremental_row_tmp
    AND #3
    STA SPR_T
    LDA m4_incremental_row_tmp
    LSR
    LSR
    CLC
    ADC m4_game_scroll_band_base
    CMP #6
    BCC glyph_addr_bank_ready
    SEC
    SBC #6
glyph_addr_bank_ready
    STA m4_incremental_bank_tmp
    TAX
    LDA m4_font_bank_pages,X
    CLC
    ADC SPR_T
    STA SPR_DST+1
    LDA SPR_COL
    CLC
    ADC m4_game_scroll_x
    AND #$1F
    ASL
    ASL
    ASL
    STA SPR_DST
    LDA SPR_Y
    AND #7
    CLC
    ADC SPR_DST
    STA SPR_DST
    RTS

pix_rev                        ; 2-bit pixel order reversed within a byte (horizontal flip)
	dta $00,$40,$80,$C0,$10,$50,$90,$D0,$20,$60,$A0,$E0,$30,$70,$B0,$F0
	dta $04,$44,$84,$C4,$14,$54,$94,$D4,$24,$64,$A4,$E4,$34,$74,$B4,$F4
	dta $08,$48,$88,$C8,$18,$58,$98,$D8,$28,$68,$A8,$E8,$38,$78,$B8,$F8
	dta $0C,$4C,$8C,$CC,$1C,$5C,$9C,$DC,$2C,$6C,$AC,$EC,$3C,$7C,$BC,$FC
	dta $01,$41,$81,$C1,$11,$51,$91,$D1,$21,$61,$A1,$E1,$31,$71,$B1,$F1
	dta $05,$45,$85,$C5,$15,$55,$95,$D5,$25,$65,$A5,$E5,$35,$75,$B5,$F5
	dta $09,$49,$89,$C9,$19,$59,$99,$D9,$29,$69,$A9,$E9,$39,$79,$B9,$F9
	dta $0D,$4D,$8D,$CD,$1D,$5D,$9D,$DD,$2D,$6D,$AD,$ED,$3D,$7D,$BD,$FD
	dta $02,$42,$82,$C2,$12,$52,$92,$D2,$22,$62,$A2,$E2,$32,$72,$B2,$F2
	dta $06,$46,$86,$C6,$16,$56,$96,$D6,$26,$66,$A6,$E6,$36,$76,$B6,$F6
	dta $0A,$4A,$8A,$CA,$1A,$5A,$9A,$DA,$2A,$6A,$AA,$EA,$3A,$7A,$BA,$FA
	dta $0E,$4E,$8E,$CE,$1E,$5E,$9E,$DE,$2E,$6E,$AE,$EE,$3E,$7E,$BE,$FE
	dta $03,$43,$83,$C3,$13,$53,$93,$D3,$23,$63,$A3,$E3,$33,$73,$B3,$F3
	dta $07,$47,$87,$C7,$17,$57,$97,$D7,$27,$67,$A7,$E7,$37,$77,$B7,$F7
	dta $0B,$4B,$8B,$CB,$1B,$5B,$9B,$DB,$2B,$6B,$AB,$EB,$3B,$7B,$BB,$FB
	dta $0F,$4F,$8F,$CF,$1F,$5F,$9F,$DF,$2F,$6F,$AF,$EF,$3F,$7F,$BF,$FF

;; clear the six charsets (6 KB at vramfont), for the test frame
clear_charsets
    LDA #<vramfont
    STA SPR_DST
    LDA #>vramfont
    STA SPR_DST+1
    LDX #24                     ; 24 pages
cc_page
    LDY #0
    LDA #0
cc_byte
    STA (SPR_DST),Y
    INY
    BNE cc_byte
    INC SPR_DST+1
    DEX
    BNE cc_page
    RTS

TL_V=$BF10
TL_X=$BF11
TL_B=$BF12
TL_A=$BF13
TL_W=$BF14
TL_H=$BF15
TL_C0=$BF16
TL_Y0=$BF17
TL_DPH=$BF2F                   ; destination pixel phase, independent of source shift
TL_K=$BF18
TL_L=$BF19
TL_P=$F4                       ; 2 bytes, zero page (indirect addressing)
TL_I=$BF1C
TL_J=$BF1D
TL_DC=$BF1E
TL_FL=$BF21                    ; square_orientation: bit7 = flip X, bit6 = flip Y
TL_SK=$BF22                    ; source column (after flip)
TL_SL=$BF23                    ; source line within sprite (after flip)
TL_T=$BF27                     ; temporaries for the transparent write
TL_N=$BF28
TL_O=$BF29
TL_PH=$BF2B                    ; pixel phase of the sprite (0..3 pixels into the first byte)
TL_MAP=$BF30
TL_TAIL=$BF2E                  ; valid pixels in the final destination byte
TL_PC=$BF40
TL_MAP_TMP=$BF44
TL_XD=$BF45
TL_PAL=$BF47
TL_S=$BF2C                     ; 2*phase: bits shifted right
TL_T8=$BF2D                    ; 8-2*phase: bits brought in from the previous column
TL_Q=$E0                       ; 2 bytes, zero page: pointer to the previous column (phase shift)

tile_colbase_lo
    :32 dta <(sprite_test_data+[#*81])
tile_colbase_hi
    :32 dta >(sprite_test_data+[#*81])
tt_tail_mask
    dta $00,$C0,$F0,$FC,$FF
tt_lead_mask
    dta $FF,$3F,$0F,$03

; Traverse only the visible world background and feed sprites to tt_draw.
bg_tiles_test
    LDA screen_start_square_x_low
    LSR
    LSR
    LSR
    LSR
    LSR
    LSR
    STA screen_start_square_x_low_tiles
    LDA screen_start_square_y_low
    LSR
    LSR
    LSR
    STA screen_start_square_y_low_tiles
    LDA #$FF
    STA TL_J
tt_j
    LDA #$FF
    STA TL_I
tt_i
    LDA screen_start_square_x
    CLC
    ADC TL_I
    STA square_x
    LDA screen_start_square_y
    CLC
    ADC TL_J
    STA square_y
    LDA background_processing_flag
    PHA
    LDA #0
    STA background_processing_flag
    JSR determine_background
    STA TL_V
    PLA
    STA background_processing_flag
    LDA TL_V
    JSR setup_background_sprite_values_from_08_09
    LDA TL_V
    CMP #$19
    BNE tt_sprite_present
    JMP tt_next
tt_sprite_present
    TAX
    LDA background_sprite_lookup,X
    AND #$7F
    STA TL_X
    LDX TL_X
    LDA sprite_height_lookup,X
    LSR
    LDA sprite_width_lookup,X
    ROR
    AND #$80
    ROR
    EOR square_orientation
    STA TL_FL
    LDX TL_X
    LDA sprite_offset_a_lookup,X
    STA TL_A
    LDA TL_I
    ASL
    ASL
    STA TL_C0
    LDA this_object_x_low
    SEC
    SBC screen_start_square_x_low
    STA TL_XD
    BCC tt_xdelta_negative
    LSR
    LSR
    LSR
    LSR
    LSR
    LSR
    JMP tt_xdelta_add
tt_xdelta_negative
    LDA TL_XD
    LSR
    LSR
    LSR
    LSR
    LSR
    LSR
    SEC
    SBC #4
tt_xdelta_add
    CLC
    ADC TL_C0
    STA TL_C0
    LDA TL_XD
    LSR
    LSR
    LSR
    LSR
    AND #3
    STA TL_MAP_TMP
    STA TL_DPH
    LDA TL_A
    LSR
    LSR
    LSR
    LSR
    AND #3
    STA TL_T
    LDA TL_MAP_TMP
    SEC
    SBC TL_T
    AND #3
    STA TL_PH
    LDA sprite_width_lookup,X   ; columns = ceil((px + phase) / 4), px = width>>4, phase = (a>>4)&3 (plotter)
    LSR
    LSR
    LSR
    LSR
    STA TL_W
    LDA TL_MAP_TMP
    CLC
    ADC TL_W
    CLC
    ADC #3
    LSR
    LSR
    STA TL_W
    LDA TL_PH
    ASL
    STA TL_S
    LDA #8
    SEC
    SBC TL_S
    STA TL_T8
    LDX TL_X
    LDA sprite_height_lookup,X
    LSR
    LSR
    LSR
    STA TL_H
    LDA TL_A                    ; column = (rowbyteoffset of a) & $1f
    ASL
    ADC #0
    ASL
    ADC #0
    AND #$1F
    STA TL_A
    LDA TL_X
    CMP #$5F
    BNE tt_source_col_done
    INC TL_A
    LDA TL_A
    AND #$1F
    STA TL_A
tt_source_col_done
    LDA TL_J                    ; dest first line = j*32 - (y_low>>3)
    ASL
    ASL
    ASL
    ASL
    ASL
    SEC
    SBC screen_start_square_y_low_tiles
    STA TL_Y0
    LDX TL_X
    LDA this_object_y_low
    CLC
    ADC sprite_height_lookup,X
    LSR
    LSR
    LSR
    STA TL_MAP_TMP
    LDA sprite_height_lookup,X
    LSR
    LSR
    LSR
    STA TL_O
    LDA TL_MAP_TMP
    SEC
    SBC TL_O
    CLC
    ADC TL_Y0
    STA TL_Y0
; Plot one transparent, palette-mapped 2bpp sprite into the native charset.
tt_draw                      ; TL_X, TL_FL, TL_A/B/W/H, TL_C0/Y0 set
    LDA this_object_palette
    STA TL_PAL
    LDX TL_X
    LDA TL_PAL
    AND #$0F
    TAY
    LDA palette_value_to_pixel_lookup,Y
    AND #$01
    STA TL_PC+1
    LDA palette_value_to_pixel_lookup,Y
    LSR
    AND #$02
    ORA TL_PC+1
    STA TL_PC+1
    LDA palette_value_to_pixel_lookup,Y
    LSR
    AND #$01
    STA TL_PC+2
    LDA palette_value_to_pixel_lookup,Y
    LSR
    LSR
    AND #$02
    ORA TL_PC+2
    STA TL_PC+2
    LDA TL_PAL
    LSR
    LSR
    LSR
    LSR
    AND #$03
    STA TL_PC+3
    LDA #0
    STA TL_PC
; No colour swap here. The plotter's $01/$02, $10/$20, $11/$22 exchange
; (odd screen X, odd-width X-flip, sprite_offset_a bit 4) only moves a pixel
; between the left and right halves of a Mode 2 byte; the colour index of each
; source pixel is unchanged. Pixel phase is handled by TL_PH/TL_DPH instead.
    LDX #0
tt_palette_map
    TXA
    LSR
    LSR
    TAY
    LDA TL_PC,Y
    ASL
    ASL
    STA TL_MAP_TMP
    TXA
    AND #$03
    TAY
    LDA TL_PC,Y
    ORA TL_MAP_TMP
    STA TL_MAP,X
    INX
    CPX #16
    BNE tt_palette_map
    INC TL_H                    ; sprite height is encoded as height - 1
        LDA m4_incremental_clip
        BEQ tt_incremental_probe_done
        LDX TL_X
        LDA sprite_width_lookup,X
        LSR
        LSR
        LSR
        LSR
        CLC
        ADC TL_DPH
        CLC
        ADC #4
        LSR
        LSR
        STA TL_W
        INC TL_W                    ; include the far edge cell in dirty overlap checks
        JSR m4_incremental_object_has_dirty
        BCS tt_incremental_probe_done
        JMP tt_kend
tt_incremental_probe_done
    LDX TL_X
    LDA #0
    BIT TL_FL
    BVC tt_source_start
    LDX TL_X
    LDA sprite_height_lookup,X
    AND #$F8
tt_source_start
    STA TL_O
    LDX TL_X
    LDA sprite_offset_b_lookup,X
    CLC
    ADC TL_O
    ADC #$00                    ; preserve carry from packed b + height
    ASL
    ADC #$00                    ; rotate left through carry twice, as plotter
    ASL
    ADC #$00
    STA TL_O
    AND #$0F
    ASL
    ASL
    ASL
    STA TL_B
    LDA TL_O
    LSR
    LSR
    LSR
    LSR
    LSR
    ORA TL_B
    STA TL_B                    ; source row decoded from the rotated byte address
    LDA TL_FL
    BPL tt_phase_ready
    LDX TL_X
    LDA sprite_width_lookup,X
    LSR
    LSR
    LSR
    LSR
    CLC
    ADC TL_T
    CLC
    ADC TL_DPH
    CLC
    ADC #1
    AND #3
    STA TL_PH                    ; phase from the flipped edge of the source
    ASL
    STA TL_S
    LDA #8
    SEC
    SBC TL_S
    STA TL_T8
tt_phase_ready
    LDX TL_X
    LDA sprite_width_lookup,X
    LSR
    LSR
    LSR
    LSR
    CLC
    ADC TL_DPH
    STA TL_MAP_TMP
    CLC
    ADC #4
    LSR
    LSR
    STA TL_W
    LDA TL_FL
    BMI tt_source_column_hflip
    LDA TL_T
    CMP TL_DPH
    BCC tt_source_column_ready
    BEQ tt_source_column_ready
    INC TL_A
    LDA TL_A
    AND #$1F
    STA TL_A
    JMP tt_source_column_ready
tt_source_column_hflip
    LDX TL_X
    LDA sprite_width_lookup,X
    LSR
    LSR
    LSR
    LSR
    CLC
    ADC TL_DPH
    AND #3
    CLC
    ADC TL_T
    CMP #3
    BCS tt_source_column_ready
    DEC TL_A
    LDA TL_A
    AND #$1F
    STA TL_A
tt_source_column_ready
    LDA TL_MAP_TMP
    AND #3
    CLC
    ADC #1
    STA TL_TAIL
    LDA #0
    STA TL_K
tt_k
    LDA TL_K
    CMP TL_W
    BNE tt_k_go
    JMP tt_kend
tt_k_go
    LDA TL_C0                   ; dest column (clip to 0..31)
    CLC
    ADC TL_K
    STA TL_DC
    CMP #32
    BCC tt_kin
    JMP tt_kskip
tt_kin
    LDA TL_K                    ; source column: reversed when flipped in X
    BIT TL_FL
    BPL tt_sk_nf
    LDA TL_W
    SEC
    SBC #1
    SEC
    SBC TL_K
tt_sk_nf
    STA TL_SK
    LDA TL_A                    ; source column (wraps in 32 columns)
    CLC
    ADC TL_SK
    AND #$1F
    TAX
    LDA tile_colbase_lo,X
    STA TL_P
    LDA tile_colbase_hi,X
    STA TL_P+1
    LDA TL_A                    ; adjacent source column for phase alignment
    CLC
    ADC TL_SK
    BIT TL_FL
    BMI tt_q_next
    SEC
    SBC #1
    JMP tt_q_ready
tt_q_next
    CLC
    ADC #1
tt_q_ready
    AND #$1F
    TAX
    LDA tile_colbase_lo,X
    STA TL_Q
    LDA tile_colbase_hi,X
    STA TL_Q+1
    LDA #0
    STA TL_L
tt_l
    LDA TL_L
    CMP TL_H
    BNE tt_lgo
    JMP tt_kskip
tt_lgo
    LDA TL_B                    ; select source row in the current column
    BIT TL_FL
    BVC tt_sl_forward
    SEC
    SBC TL_L                    ; unflipped plotter advances the pointer backward
    JMP tt_sl_done
tt_sl_forward
    CLC
    ADC TL_L                    ; V-flipped plotter advances the pointer forward
tt_sl_done
tt_sl_nf
    STA TL_SL
    LDA TL_SL
    CMP #81
    BCC tt_lin
    JMP tt_lskip
tt_lin
    TAY
    LDA (TL_P),Y
    BIT TL_FL                   ; flipped in X: reverse the 2-bit pixels of the byte
    BMI tt_fx
    JMP tt_nofx
tt_fx
    TAX
    LDA pix_rev,X
tt_nofx
    LDX TL_PH
    BEQ tt_nophase
    STA TL_O                    ; current byte
    LDA (TL_Q),Y                ; previous column, same line
    BIT TL_FL
    BPL tt_phase_neighbor_ready
    TAX
    LDA pix_rev,X
tt_phase_neighbor_ready
    STA TL_N
    LDA TL_O
    LDX TL_S
    BEQ tt_shr_done
tt_shr
    LSR
    DEX
    BNE tt_shr
tt_shr_done
    STA TL_O
    LDA TL_N
    LDX TL_T8
tt_shl
    ASL
    DEX
    BNE tt_shl
    ORA TL_O
tt_nophase
    STA TL_O
    AND #$0F
    TAX
    LDA TL_MAP,X
    STA TL_N
    LDA TL_O
    LSR
    LSR
    LSR
    LSR
    TAX
    LDA TL_MAP,X
    ASL
    ASL
    ASL
    ASL
    ORA TL_N
    STA TL_T
    LDA TL_O
    LSR
    ORA TL_O
    AND #$55
    STA TL_N
    ASL
    ORA TL_N
    STA TL_N
    LDA TL_K
    BNE tt_tail_check
    LDY TL_DPH
    LDA tt_lead_mask,Y
    AND TL_N
    STA TL_N
tt_tail_check
    LDA TL_K
    CLC
    ADC #1
    CMP TL_W
    BNE tt_tail_done
    LDY TL_TAIL
    LDA tt_tail_mask,Y
    AND TL_N
    STA TL_N
tt_tail_done
    LDA TL_T
    PHA
    LDA TL_Y0                   ; dest line = Y0 + L (must be 0..191)
    CLC
    ADC TL_L
    CMP #192
    BCC tt_lok
    JMP tt_lpop
tt_lok
    STA SPR_Y
    LDA TL_DC
    STA SPR_COL
    JSR glyph_addr             ; SPR_DST already includes the line within the cell (Y&7)
        LDA m4_incremental_clip
        BEQ tt_lm4_clip_done
        LDX m4_incremental_dirty_byte
        LDA m4_incremental_work,X
        AND m4_incremental_dirty_mask
        BEQ tt_lpop
tt_lm4_clip_done
    LDY #0
    PLA
    STA TL_T
    LDA TL_N
    EOR #$FF
    AND (SPR_DST),Y             ; old pixels where the sprite pixel is 0
    STA TL_O
    LDA TL_T
    AND TL_N
    ORA TL_O
    STA (SPR_DST),Y
    JMP tt_lskip
tt_lpop
    PLA
tt_lskip
    INC TL_L
    JMP tt_l
tt_kskip
    INC TL_K
    JMP tt_k
tt_kend
    JMP tt_next

m4_incremental_object_has_dirty
    LDA #0
    STA m4_incremental_probe_line
    LDA #$FF
    STA m4_incremental_probe_row
m4_incremental_probe_line_loop
    LDA TL_Y0
    CLC
    ADC m4_incremental_probe_line
    CMP #192
    BCS m4_incremental_probe_next_line
    AND #$F8
    CMP m4_incremental_probe_row
    BEQ m4_incremental_probe_next_line
    STA m4_incremental_probe_row
    LSR
    LSR
    LSR
    CLC
    ADC m4_game_scroll_y
    STA m4_incremental_row_tmp
    AND #3
    ASL
    ASL
    STA m4_incremental_dirty_byte
    LDA m4_incremental_row_tmp
    LSR
    LSR
    CLC
    ADC m4_game_scroll_band_base
    CMP #6
    BCC m4_incremental_probe_bank_ready
    SEC
    SBC #6
m4_incremental_probe_bank_ready
    ASL
    ASL
    ASL
    ASL
    CLC
    ADC m4_incremental_dirty_byte
    STA m4_incremental_dirty_byte
    LDA #0
    STA m4_incremental_probe_col
m4_incremental_probe_col_loop
    LDA TL_C0
    CLC
    ADC m4_incremental_probe_col
    CMP #32
    BCS m4_incremental_probe_next_col
    CLC
    ADC m4_game_scroll_x
    AND #$1F
    STA m4_incremental_col_tmp
    AND #7
    TAY
    LDA m4_incremental_bit_masks,Y
    STA m4_incremental_dirty_mask
    LDA m4_incremental_col_tmp
    LSR
    LSR
    LSR
    CLC
    ADC m4_incremental_dirty_byte
    TAX
    LDA m4_incremental_work,X
    AND m4_incremental_dirty_mask
    BNE m4_incremental_probe_found
m4_incremental_probe_next_col
    INC m4_incremental_probe_col
    LDA m4_incremental_probe_col
    CMP TL_W
    BCC m4_incremental_probe_col_loop
m4_incremental_probe_next_line
    INC m4_incremental_probe_line
    LDA m4_incremental_probe_line
    CMP TL_H
m4_incremental_probe_line_continue
    BCS m4_incremental_probe_no_dirty
    JMP m4_incremental_probe_line_loop
m4_incremental_probe_no_dirty
    CLC
    RTS
m4_incremental_probe_found
    SEC
    RTS

tt_next
    INC TL_I
    LDA TL_I
    CMP #9
    BEQ tt_row
    JMP tt_i
tt_row
    INC TL_J
    LDA TL_J
    CMP #6
    BEQ tt_done
    JMP tt_j
tt_done
    RTS


screen_start_square_x_low_tiles=$BF1F
screen_start_square_y_low_tiles=$BF20
	org $B000
sprite_test_data
    ins "sprite_sheet_atari_columns_128x81.bin"

	org $02E0
    dta a(scroll_test_start)

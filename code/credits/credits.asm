incsrc "tracking.asm"
;incsrc "fonts.asm"

; Defines for the script and credits data
!speed = $f770
!set = $9a17
!delay = $9a0d
!draw = $0000
!end = $f6fe, $99fe
!blank = $1fc0
!row = $0040

!last_saveslot = $7fffe0
!timer_backup1 = $7fffe2
!timer_backup2 = $7fffe4
!softreset = $7fffe6
!scroll_speed = $7fffe8

; Patch soft reset to retain value of RTA counter
org $80844B
    jml patch_reset1
org $808490
    jml patch_reset2

; Patch loading and saving routines
org $81807f
    jmp patch_save

org $8180f7
    jmp patch_load

; Hijack loading new game to reset stats
org $828063
    jsl clear_values

; Hijack the original credits code to read the script from bank $DF
org $8b9976
    jml scroll

org $8b999b
    jml patch1 

org $8b99e5
    jml patch2

org $8b9a08
    jml patch3

org $8b9a19
    jml patch4



; Hijack when samus is in the ship and ready to leave the planet
org $a2ab13
  jsl game_end

; Patch NMI to skip resetting 05ba and instead use that as an extra time counter
org $8095e5
nmi:
    ldx #$00
    stx $05b4
    ldx $05b5
    inx
    stx $05b5
    inc $05b6
nmi_inc:
    rep #$30
    inc $05b8
    bne +
    inc $05ba
+
    bra nmi_end

org $809602
    bra nmi_inc
nmi_end:
    ply
    plx
    pla
    pld
    plb
    rti

; Patch soft reset to save the value of the RTA timer
org $80fe00
patch_reset1:
    lda !softreset ; Check if we're softresetting
    cmp #$babe
    beq save_timer
    lda #$babe
    sta !softreset
    lda #$0000
    sta !timer_backup1
    sta !timer_backup2
    sta !last_saveslot
    bra skipsave
save_timer:   
    lda !timer1
    sta !timer_backup1
    lda !timer2
    sta !timer_backup2
skipsave:
    ldx #$1ffe
    lda #$0000
-
    stz $0000,x
    dex
    dex
    bpl - 
    lda !timer_backup1
    sta !timer1
    lda !timer_backup2
    sta !timer2
    jml $808455

patch_reset2:
    lda !timer1
    sta !timer_backup1
    lda !timer2
    sta !timer_backup2
    ldx #$1ffe
-
    stz $0000,x
    stz $2000,x
    stz $4000,x
    stz $6000,x
    stz $8000,x
    stz $a000,x
    stz $c000,x
    stz $e000,x
    dex        
    dex        
    bpl -

    ldx #$00df          ; clear temp variables
    lda #$0000
-
    sta $7fff00,x
    dex
    dex
    bpl -

    lda !timer_backup1
    sta !timer1
    lda !timer_backup2
    sta !timer2
    jml $8084af

warnpc $80ff00

; Patch load and save routines
org $81ef20
patch_save:
    lda !timer1
    sta $7ffc00
    lda !timer2
    sta $7ffc02
    jsl save_stats
    lda $7e0952
    clc
    adc #$0010
    sta !last_saveslot
    ply
    plx
    clc
    plb
    plp
    rtl

patch_load:
    lda $7e0952
    clc
    adc #$0010
    cmp !last_saveslot      ; If we're loading the same save that's played last
    beq +                   ; don't restore stats from SRAM, only do this if
    jsl load_stats          ; a new save slot is loaded, or loading from hard reset
    lda $7ffc00
    sta !timer1
    lda $7ffc02
    sta !timer2
+
    ply
    plx
    clc
    plb
    rtl

; Hijack after decompression of regular credits tilemaps
org $8be0d1
    jsl copy

; Load credits script data from bank $df instead of $8c
org $8bf770
set_scroll:
    rep #$30
    phb : pea $df00 : plb : plb
    lda $0000,y
    sta !scroll_speed
    iny
    iny
    plb
    rts

scroll:
    inc $1995
    lda $1995
    cmp !scroll_speed
    beq +
    lda $1997
    jml $8b9989
+
    stz $1995
    inc $1997
    lda $1997
    jml $8b9989


patch1:
    phb : pea $df00 : plb : plb
    lda $0000,y    
    bpl +
    plb
    jml $8b99a0
+
    plb
    jml $8b99aa

patch2:
    sta $0014
    phb : pea $df00 : plb : plb
    lda $0002,y    
    plb
    jml $8b99eb

patch3:
    phb : pea $df00 : plb : plb
    lda $0000,y
    tay
    plb
    jml $8b9a0c

patch4:
    phb : pea $df00 : plb : plb
    lda $0000,y
    plb
    sta $19fb
    jml $8b9a1f

; Copy custom credits tilemap data from $ceb240,x to $7f2000,x
copy:
    pha
    phx
    ldx #$0000
-
    lda.l credits,x
    cmp #$dead
    beq +
    sta $7f2000,x
    inx
    inx
    jmp -
+

    ldx #$0000
-
    lda.l itemlocations,x
    cmp #$0000
    beq +
    sta $7fa000,x
    inx
    inx
    jmp -
+

    jsl write_stats
    lda #$0002
    sta !scroll_speed
    plx
    pla
    jsl $8b95ce
    rtl

clear_values:
    php
    rep #$30
    ; Do some checks to see that we're actually starting a new game    
    ; Make sure game mode is 1f
    lda $7e0998
    cmp.w #$001f
    bne clear_value_ret
    
    ; Check if samus saved energy is 00, if it is, run startup code
    lda $7ed7e2
    bne clear_value_ret

    ldx #$0000
    lda #$0000
-
    jsl store_stat
    inx
    cpx #$0180
    bne -

    ; Clear RTA Timer
    lda #$0000
    sta !timer1
    sta !timer2

clear_value_ret:
    plp
    jsl $809a79
    rtl

; Game has ended, save RTA timer to RAM and copy all stats to SRAM a final time
game_end: {
  lda !timer1
  sta $7ffc00
  lda !timer2
  sta $7ffc02

  ; Subtract frames from pressing down at ship to this code running
  lda $7ffc00
  sec
  sbc #$013d
  sta $7ffc00
  lda #$0000  ; if carry clear this will subtract one from the high byte of timer
  sbc $7ffc02

  jsl save_stats
  lda #$000a
  jsl $90f084
  rtl
}

org $dfd4f0
; Draw full time as hh:mm:ss:ff
; Pointer to first byte of RAM in A
draw_full_time:
    phx
    phb
    pea $7f7f : plb : plb
    tax
    lda $0000,x
    sta $16
    lda $0002,x
    sta $14
    lda #$003c
    sta $12
    lda #$ffff
    sta $1a
    jsr div32 ; frames in $14, rest in $16
    iny : iny : iny : iny : iny : iny ; Increment Y three positions forward to write the last value    
    lda $14
    jsr draw_two
    tya
    sec
    sbc #$0010
    tay     ; Skip back 8 characters to draw the top three things
    lda $16
    jsr draw_time
    plb
    plx
    rts  

; Draw time as xx:yy:zz
draw_time:
    phx
    phb
    dey : dey : dey : dey : dey : dey ; Decrement Y by 3 characters so the time count fits
    pea $7f7f : plb : plb
    sta $004204
    sep #$20
    lda #$ff
    sta $1a
    lda #$3c
    sta $004206
    pha : pla : pha : pla : rep #$20
    lda $004216 ; Seconds or Frames
    sta $12
    lda $004214 ; First two groups (hours/minutes or minutes/seconds)
    sta $004204
    sep #$20
    lda #$3c
    sta $004206
    pha : pla : pha : pla : rep #$20
    lda $004216
    sta $14
    lda $004214 ; First group (hours or minutes)
    jsr draw_two
    iny : iny ; Skip past separator
    lda $14 ; Second group (minutes or seconds)
    jsr draw_two
    iny : iny
    lda $12 ; Last group (seconds or frames)
    jsr draw_two
    plb
    plx
    rts        

; Draw 5-digit value to credits tilemap
; A = number to draw, Y = row address
draw_value:
  phx    
  phb
  pea $7f7f : plb : plb
  stz $1a     ; Leading zeroes flag

  ldx.w #100
  jsr integer_division

  lda $004216 ; Load the last two digits
  pha         ; Push last two digits onto the stack

  lda $004214 ; Load the top three digits
  jsr draw_three

  pla         ; Pull last two digits from the stack
  jsr draw_two

  plb
  plx
  rts

draw_three:
  ldx.w #100
  jsr integer_division

  lda $004214 ; Hundreds
  jsr draw_digit_without_padding
  iny : iny

  lda $004216
  ldx.w #10
  jsr integer_division

  lda $004214
  jsr draw_digit_without_padding
  iny : iny

  lda $004216
  jsr draw_digit_without_padding
  iny : iny
  rts

draw_two:
  ldx.w #10
  jsr integer_division 

  lda $004214
  cmp $1a
  beq +
  jsr draw_digit : +
  iny : iny

  lda $004216
  jsr draw_digit
  iny : iny

  rts

; A = dividend, X = divisor
; $004214 = quotient, $004216 = remainder
integer_division:
  sta $004204
  sep #$20
  txa
  sta $004206
  pha : pla : pha : pla : rep #$20
  rts

draw_digit_without_padding:
  beq +

draw_digit:
  asl
  tax
  print pc
  lda.l numbers_top,x
  sta $0034,y
  lda.l numbers_bot,x
  sta $0074,y
+ rts

warnpc $dfd635

org $dfd635
; Loop through stat table and update RAM with numbers representing those stats
write_stats:
    phy
    phb
    php
    pea $dfdf : plb : plb
    rep #$30
    jsl load_stats      ; Copy stats back from SRAM
    ldx #$0000
    ldy #$0000

write_loop:
    ; Get pointer to table
    tya
    asl : asl : asl
    tax

    ; Load stat type
    lda.l stats+4,x
    beq write_end
    cmp #$0001
    beq write_number
    cmp #$0002
    beq write_time
    cmp #$0003
    beq write_fulltime
    jmp write_continue

write_number:
    ; Load statistic
    lda.l stats,x
    jsl load_stat
    pha

    ; Load row address
    lda.l stats+2,x
    tyx
    tay
    pla
    jsr draw_value
    txy
    jmp write_continue

write_time:
    ; Load statistic
    lda.l stats,x
    jsl load_stat
    pha

    ; Load row address
    lda.l stats+2,x
    tyx
    tay
    pla
    jsr draw_time
    txy
    jmp write_continue

write_fulltime:    
    lda.l stats,x        ; Get stat id
    asl
    clc
    adc #$fc00          ; Get pointer to value instead of actual value
    pha

    ; Load row address
    lda.l stats+2,x
    tyx
    tay
    pla
    jsr draw_full_time
    txy
    jmp write_continue

write_continue:
    iny
    jmp write_loop

write_end:
    plp
    plb
    ply
    rtl

; 32-bit by 16-bit division routine I found somewhere
div32: 
    phy
    phx             
    php
    rep #$30
    sep #$10
    sec
    lda $14
    sbc $12
    bcs uoflo
    ldx #$11
    rep #$10

ushftl:
    rol $16
    dex
    beq umend
    rol $14
    lda #$0000
    rol
    sta $18
    sec
    lda $14
    sbc $12
    tay
    lda $18
    sbc #$0000
    bcc ushftl
    sty $14
    bra ushftl
uoflo:
    lda #$ffff
    sta $16
    sta $14
umend:
    plp
    plx
    ply
    rts

numbers_top:
    dw $0060, $0061, $0062, $0063, $0064, $0065, $0066, $0067, $0068, $0069, $006a, $006b, $006c, $006d, $006e, $006f
numbers_bot:
    dw $0070, $0071, $0072, $0073, $0074, $0075, $0076, $0077, $0078, $0079, $007a, $007b, $007c, $007d, $007e, $007f 

load_stats:
    phx
    pha
    ldx #$0000
    lda $7e0952
    bne +
-
    lda $701400,x
    sta $7ffc00,x
    inx
    inx
    cpx #$0300
    bne -
    jmp load_end
+   
    cmp #$0001
    bne +
    lda $701700,x
    sta $7ffc00,x
    inx
    inx
    cpx #$0300
    bne -
    jmp load_end
+   
    lda $701a00,x
    sta $7ffc00,x
    inx
    inx
    cpx #$0300
    bne -
    jmp load_end

load_end:
    pla
    plx
    rtl

save_stats:
    phx
    pha
    ldx #$0000
    lda $7e0952
    bne +
-
    lda $7ffc00,x
    sta $701400,x
    inx
    inx
    cpx #$0300
    bne -
    jmp save_end
+   
    cmp #$0001
    bne +
    lda $7ffc00,x
    sta $701700,x
    inx
    inx
    cpx #$0300
    bne -
    jmp save_end
+   
    lda $7ffc00,x
    sta $701a00,x
    inx
    inx
    cpx #$0300
    bne -
    jmp save_end

save_end:
    pla
    plx
    rtl

warnpc $dfd800

macro DrawRow(index)
    dw !draw, !row*<index>
endmacro

macro Blank()
    dw !draw, !blank
endmacro

; New credits script in free space of bank $DF
org $dfd91b
script:
    dw !set, $0002 : -
    dw !draw, !blank
    dw !delay, -
    
    ; Show a compact version of the original credits so we get time to add more    
    %DrawRow(0)      ; SUPER METROID STAFF
    %Blank()
    %DrawRow(4)      ; PRODUCER
    %Blank()
    %DrawRow(7)      ; MAKOTO KANOH
    %DrawRow(8)       
    %Blank()
    %DrawRow(9)      ; DIRECTOR
    %Blank()
    %DrawRow(10)     ; YOSHI SAKAMOTO
    %DrawRow(11)
    %Blank()
    %DrawRow(12)     ; BACK GROUND DESIGNERS
    %Blank()
    %DrawRow(13)     ; HIROFUMI MATSUOKA
    %DrawRow(14)
    %Blank()
    %DrawRow(15)     ; MASAHIKO MASHIMO
    %DrawRow(16)     
    %Blank()
    %DrawRow(17)     ; HIROYUKI KIMURA
    %DrawRow(18)     
    %Blank()
    %DrawRow(19)     ; OBJECT DESIGNERS
    %Blank()
    %DrawRow(20)     ; TOHRU OHSAWA
    %DrawRow(21)     
    %Blank()
    %DrawRow(22)     ; TOMOYOSHI YAMANE
    %DrawRow(23)    
    %Blank()
    %DrawRow(24)     ; SAMUS ORIGINAL DESIGNERS
    %Blank()
    %DrawRow(25)     ; HIROJI KIYOTAKE
    %DrawRow(26)    
    %Blank()
    %DrawRow(27)     ; SAMUS DESIGNER
    %Blank()
    %DrawRow(28)     ; TOMOMI YAMANE
    %DrawRow(29)    
    %Blank()
    %DrawRow(83)     ; SOUND PROGRAM
    %DrawRow(107)    ; AND SOUND EFFECTS
    %Blank()
    %DrawRow(84)     ; KENJI YAMAMOTO
    %DrawRow(85)    
    %Blank()
    %DrawRow(86)     ; MUSIC COMPOSERS
    %Blank()
    %DrawRow(84)     ; KENJI YAMAMOTO
    %DrawRow(85)    
    %Blank()
    %DrawRow(87)     ; MINAKO HAMANO
    %DrawRow(88)    
    %Blank()
    %DrawRow(30)     ; PROGRAM DIRECTOR
    %Blank()
    %DrawRow(31)     ; KENJI IMAI
    %DrawRow(64)    
    %Blank()
    %DrawRow(65)     ; SYSTEM COORDINATOR
    %Blank()
    %DrawRow(66)     ; KENJI NAKAJIMA
    %DrawRow(67)    
    %Blank()
    %DrawRow(68)     ; SYSTEM PROGRAMMER
    %Blank()
    %DrawRow(69)     ; YOSHIKAZU MORI
    %DrawRow(70)    
    %Blank()
    %DrawRow(71)     ; SAMUS PROGRAMMER
    %Blank()
    %DrawRow(72)     ; ISAMU KUBOTA
    %DrawRow(73)    
    %Blank()
    %DrawRow(74)     ; EVENT PROGRAMMER
    %Blank()
    %DrawRow(75)     ; MUTSURU MATSUMOTO
    %DrawRow(76)    
    %Blank()
    %DrawRow(77)     ; ENEMY PROGRAMMER
    %Blank()
    %DrawRow(78)     ; YASUHIKO FUJI
    %DrawRow(79)    
    %Blank()
    %DrawRow(80)     ; MAP PROGRAMMER
    %Blank()
    %DrawRow(81)     ; MOTOMU CHIKARAISHI
    %DrawRow(82)    
    %Blank()
    %DrawRow(101)    ; ASSISTANT PROGRAMMER
    %Blank()
    %DrawRow(102)    ; KOUICHI ABE
    %DrawRow(103)   
    %Blank()
    %DrawRow(104)    ; COORDINATORS
    %Blank()
    %DrawRow(105)    ; KATSUYA YAMANO
    %DrawRow(106)   
    %Blank()
    %DrawRow(63)     ; TSUTOMU KANESHIGE
    %DrawRow(96)   
    %Blank()
    %DrawRow(89)    ; PRINTED ART WORK
    %Blank()
    %DrawRow(90)    ; MASAFUMI SAKASHITA
    %DrawRow(91)   
    %Blank()
    %DrawRow(92)    ; YASUO INOUE
    %DrawRow(93)   
    %Blank()
    %DrawRow(94)    ; MARY COCOMA
    %DrawRow(95)   
    %Blank()
    %DrawRow(99)    ; YUSUKE NAKANO
    %DrawRow(100)   
    %Blank()
    %DrawRow(108)   ; SHINYA SANO
    %DrawRow(109)   
    %Blank()
    %DrawRow(110)   ; NORIYUKI SATO
    %DrawRow(111)   
    %Blank()
    %DrawRow(32)    ; SPECIAL THANKS TO
    %Blank()
    %DrawRow(33)    ; DAN OWSEN
    %DrawRow(34)   
    %Blank()
    %DrawRow(35)    ; GEORGE SINFIELD
    %DrawRow(36)   
    %Blank()
    %DrawRow(39)    ; MASARU OKADA
    %DrawRow(40)   
    %Blank()
    %DrawRow(43)    ; TAKAHIRO HARADA
    %DrawRow(44)   
    %Blank()
    %DrawRow(47)    ; KOHTA FUKUI
    %DrawRow(48)   
    %Blank()
    %DrawRow(49)    ; KEISUKE TERASAKI
    %DrawRow(50)   
    %Blank()
    %DrawRow(51)    ; MASARU YAMANAKA
    %DrawRow(52)   
    %Blank()
    %DrawRow(53)    ; HITOSHI YAMAGAMI
    %DrawRow(54)   
    %Blank()
    %DrawRow(57)    ; NOBUHIRO OZAKI
    %DrawRow(58)   
    %Blank()
    %DrawRow(59)    ; KENICHI NAKAMURA
    %DrawRow(60)   
    %Blank()
    %DrawRow(61)    ; TAKEHIKO HOSOKAWA
    %DrawRow(62)   
    %Blank()
    %DrawRow(97)    ; SATOSHI MATSUMURA
    %DrawRow(98)   
    %Blank()
    %DrawRow(122)   ; TAKESHI NAGAREDA
    %DrawRow(123)  
    %Blank()
    %DrawRow(124)   ; MASAHIRO KAWANO
    %DrawRow(125)  
    %Blank()
    %DrawRow(45)    ; HIRO YAMADA
    %DrawRow(46)  
    %Blank()
    %DrawRow(112)   ; AND ALL OF R&D1 STAFFS
    %DrawRow(113)  
    %Blank()
    %DrawRow(114)   ; GENERAL MANAGER
    %Blank()
    %DrawRow(5)     ; GUMPEI YOKOI
    %DrawRow(6)  
    %Blank()
    %Blank()
    %Blank()

    ; Custom item randomizer credits text        

    %DrawRow(128)  ; Randomizer staff
    %Blank()
    %Blank()
    %DrawRow(163)  ; Game balance
    %Blank()
    %DrawRow(165)  ; kipp
    %DrawRow(166)
    %Blank()
    %Blank()
    %DrawRow(129)  ; Rando code
    %Blank()
    %DrawRow(130)  ; total
    %DrawRow(131)
    %Blank()
    %DrawRow(132)  ; dessyreqt
    %DrawRow(133)
    %Blank()
    %Blank()
    %DrawRow(141)  ; ROM patches
    %Blank()
    %DrawRow(137)  ; andreww
    %DrawRow(138)
    %Blank()
    %DrawRow(146)  ; leodox
    %DrawRow(147)
    %Blank()
    %DrawRow(139)  ; personitis
    %DrawRow(140)
    %Blank()
    %DrawRow(142)  ; smiley
    %DrawRow(143)
    %Blank()
    %DrawRow(130)  ; total
    %DrawRow(131)
    %Blank()
    %Blank()
    %DrawRow(162)  ; Logo design
    %Blank()
    %DrawRow(160)  ; minimemys
    %DrawRow(161)
    %Blank()
    %Blank()
    %DrawRow(157)  ; Technical Support
    %Blank()
    %DrawRow(158)  ; masshesteria
    %DrawRow(159)
    %Blank()
    %Blank()
    %DrawRow(148)  ; Special thanks to
    %Blank()
    %DrawRow(154)  ; Testers
    %Blank()
    %DrawRow(137)  ; andreww
    %DrawRow(138)
    %Blank()
    %DrawRow(155)  ; fbs
    %DrawRow(156)
    %Blank()
    %DrawRow(171)  ; maniacal
    %DrawRow(172)
    %Blank()
    %DrawRow(173)  ; osse
    %DrawRow(174)
    %Blank()
    %DrawRow(135)  ; rumble
    %DrawRow(136)
    %Blank()
    %DrawRow(144)  ; sloaters
    %DrawRow(145)
    %Blank()
    %DrawRow(167)  ; tracie
    %DrawRow(168)
    %Blank()
    %DrawRow(169)  ; zeb
    %DrawRow(170)
    %Blank()
    %Blank()
    %DrawRow(149)  ; Disassembly
    %Blank()
    %DrawRow(150)
    %DrawRow(151)
    %Blank()
    %DrawRow(152)
    %DrawRow(153)
    %Blank()
    %Blank()
    %DrawRow(175)  ; Metroid construction
    %Blank()
    %DrawRow(176)
    %DrawRow(177)
    %Blank()
    %Blank()
    %DrawRow(178)  ; SRL
    %Blank()
    %DrawRow(179)
    %DrawRow(180)
    %Blank()
    %Blank()
    %DrawRow(164)  ; Play this randomizer at
    %Blank()
    %DrawRow(181)
    %DrawRow(182)
    %Blank()
    
    %Blank()
    %DrawRow(183)  ; Game play stats
    %Blank()
    %Blank()
    %DrawRow(184)  ; Doors
    %Blank()

    ; Set scroll speed to 3 frames per pixel
    dw !speed, $0003
    %DrawRow(185)
    %DrawRow(186)
    %Blank()
    %DrawRow(187)
    %DrawRow(188)
    %Blank()
    %DrawRow(189)
    %DrawRow(190)
    %Blank()
    %Blank()
    %DrawRow(191)
    %Blank()
    %DrawRow(192)
    %DrawRow(193)
    %Blank()
    %DrawRow(194)
    %DrawRow(195)
    %Blank()
    %DrawRow(196)
    %DrawRow(197)
    %Blank()
    %DrawRow(198)
    %DrawRow(199)
    %Blank()
    %DrawRow(200)
    %DrawRow(201)
    %Blank()
    %DrawRow(202)
    %DrawRow(203)
    %Blank()
    %Blank()
    %DrawRow(204)
    %Blank()
    %DrawRow(205)
    %DrawRow(206)
    %Blank()
    %DrawRow(207)
    %DrawRow(208)
    %Blank()
    %DrawRow(209)
    %DrawRow(210)
    %Blank()
    %DrawRow(211)
    %DrawRow(212)
    %Blank()
    %DrawRow(213)
    %DrawRow(214)
    %Blank()
    %DrawRow(215)
    %DrawRow(216)

   
    ; Draw item locations
    %Blank()
    %Blank()
    %DrawRow(640)
    %Blank()
    %Blank()
    %DrawRow(641)
    %DrawRow(642)
    %Blank()
    %DrawRow(643)
    %DrawRow(644)
    %Blank()
    %DrawRow(645)
    %DrawRow(646)
    %Blank()
    %DrawRow(647)
    %DrawRow(648)
    %Blank()
    %DrawRow(649)
    %DrawRow(650)
    %Blank()
    %DrawRow(651)
    %DrawRow(652)
    %Blank()
    %DrawRow(653)
    %DrawRow(654)
    %Blank()
    %DrawRow(655)
    %DrawRow(656)
    %Blank()
    %DrawRow(657)
    %DrawRow(658)
    %Blank()
    %DrawRow(659)
    %DrawRow(660)
    %Blank()
    %DrawRow(661)
    %DrawRow(662)
    %Blank()
    %DrawRow(663)
    %DrawRow(664)
    %Blank()
    %DrawRow(665)
    %DrawRow(666)
    %Blank()
    %DrawRow(667)
    %DrawRow(668)
    %Blank()
    %DrawRow(669)
    %DrawRow(670)
    %Blank()
    %DrawRow(671)
    %DrawRow(672)

    %Blank()
    %Blank()
    %Blank()
    %Blank()
    %Blank()
    %Blank()
    %DrawRow(217)
    %DrawRow(218)
    %Blank()
    %Blank()
    %DrawRow(219)
    %DrawRow(220)        
    %Blank()
    %Blank()
    %Blank()
    %Blank()
    %Blank()
    %Blank()
    %Blank()
    %Blank()
    %Blank()

    ; Set scroll speed to 4 frames per pixel
    dw !speed, $0004
   
    ; Scroll all text off and end credits
    dw !set, $0017 : -
    %Blank()
    dw !delay, -    
    dw !end

stats:
    ; STAT ID, ADDRESS,    TYPE (1 = Number, 2 = Time, 3 = Full time), UNUSED
    dw 0,       !row*217,  3, 0    ; Full RTA Time
    dw 2,       !row*185,  1, 0    ; Door transitions
    dw 3,       !row*187,  3, 0    ; Time in doors
    dw 5,       !row*189,  2, 0    ; Time adjusting doors
    dw 7,       !row*192,  3, 0    ; Crateria
    dw 9,       !row*194,  3, 0    ; Brinstar
    dw 11,      !row*196,  3, 0    ; Norfair
    dw 13,      !row*198,  3, 0    ; Wrecked Ship
    dw 15,      !row*200,  3, 0    ; Maridia
    dw 17,      !row*202,  3, 0    ; Tourian
    dw 20,      !row*205,  1, 0    ; Charged Shots
    dw 21,      !row*207,  1, 0    ; Special Beam Attacks
    dw 22,      !row*209,  1, 0    ; Missiles
    dw 23,      !row*211,  1, 0    ; Super Missiles
    dw 24,      !row*213,  1, 0    ; Power Bombs
    dw 26,      !row*215,  1, 0    ; Bombs
    dw 0,               0,  0, 0    ; end of table

warnpc $dfffff

macro font1(str,color)
    pushtable
    table "tables/<color>_single.tbl",rtl
    dw "<str>"
    pulltable
endmacro

macro font2(str,color)
    pushtable
    table "tables/<color>_double_top.tbl"
    dw "<str>"
    table "tables/<color>_double_bottom.tbl"
    dw "<str>"
    pulltable
endmacro

; Relocated credits tilemap to free space in bank CE
org $ceb240
credits:
    ; Single line characters:
    ;   ABCDEFGHIJKLMNOPQRSTUVWXYZ.,':!
    ; Double line characters:
    ;   ABCDEFGHIJKLMNOPQRSTUVWXYZ.^':%&
    ;   0123456789
    
    %font1("     DASH RANDOMIZER STAFF      ", "pink")    ; 128
    %font1("        RANDOMIZER CODE         ", "purple")  ; 129
    %font2("             TOTAL              ", "white")   ; 130 + 131
    %font2("           DESSYREQT            ", "white")   ; 132 + 133
    %font1("           SNES CODE            ", "purple")  ; 134
    %font2("          RUMBLEMINZE           ", "white")   ; 135 + 136
    %font2("            ANDREWW             ", "white")   ; 137 + 138
    %font2("           PERSONITIS           ", "white")   ; 139 + 140
    %font1("          ROM PATCHES           ", "purple")  ; 141
    %font2("             SMILEY             ", "white")   ; 142 + 143
    %font2("           SLOATERS27           ", "white")   ; 144 + 145
    %font2("             LEODOX             ", "white")   ; 146 + 147
    %font1("       SPECIAL THANKS TO        ", "cyan")    ; 148
    %font1("   SUPER METROID DISASSEMBLY    ", "yellow")  ; 149
    %font2("             PJBOY              ", "white")   ; 150 + 151
    %font2("            KEJARDON            ", "white")   ; 152 + 153
    %font1("            TESTERS             ", "yellow")  ; 154
    %font2("         FRUITBATSALAD          ", "white")   ; 155 + 156
    %font1("       TECHNICAL SUPPORT        ", "purple")  ; 157
    %font2("          MASSHESTERIA          ", "white")   ; 158 + 159
    %font2("           MINIMEMYS            ", "white")   ; 160 + 161
    %font1("          LOGO DESIGN           ", "purple")  ; 162
    %font1("          GAME BALANCE          ", "purple")  ; 163
    %font1("     PLAY THIS RANDOMIZER AT    ", "cyan")    ; 164
    %font2("              KIPP              ", "white")   ; 165 + 166
    %font2("            TRACIEM             ", "white")   ; 167 + 168
    %font2("             ZEB316             ", "white")   ; 169 + 170
    %font2("           MANIACAL42           ", "white")   ; 171 + 172
    %font2("            OSSE101             ", "white")   ; 173 + 174
    %font1("      METROID CONSTRUCTION      ", "yellow")  ; 175
    %font2("     METROIDCONSTRUCTION.COM    ", "white")   ; 176 + 177
    %font1("  SUPER METROID SRL COMMUNITY   ", "yellow")  ; 178
    %font2("    DISCORD INVITE : 6RYJM4M    ", "white")   ; 179 + 180
    %font2("      DASHRANDO.GITHUB.IO       ", "white")   ; 181 + 182
    %font1("      GAMEPLAY STATISTICS       ", "purple")  ; 183
    %font1("             DOORS              ", "orange")  ; 184
    %font2(" DOOR TRANSITIONS               ", "white")   ; 185 + 186
    %font2(" TIME IN DOORS      00'00'00^00 ", "white")   ; 187 + 188
    %font2(" TIME ALIGNING DOORS   00'00^00 ", "white")   ; 189 + 190
    %font1("         TIME SPENT IN          ", "blue")    ; 191
    %font2(" CRATERIA           00'00'00^00 ", "white")   ; 192 + 193
    %font2(" BRINSTAR           00'00'00^00 ", "white")   ; 194 + 195
    %font2(" NORFAIR            00'00'00^00 ", "white")   ; 196 + 197
    %font2(" WRECKED SHIP       00'00'00^00 ", "white")   ; 198 + 199
    %font2(" MARIDIA            00'00'00^00 ", "white")   ; 200 + 201
    %font2(" TOURIAN            00'00'00^00 ", "white")   ; 202 + 203
    %font1("      SHOTS AND AMMO FIRED      ", "green")   ; 204
    %font2(" CHARGED SHOTS                  ", "white")   ; 205 + 206
    %font2(" SPECIAL BEAM ATTACKS           ", "white")   ; 207 + 208
    %font2(" MISSILES                       ", "white")   ; 209 + 210
    %font2(" SUPER MISSILES                 ", "white")   ; 211 + 212
    %font2(" POWER BOMBS                    ", "white")   ; 213 + 214
    %font2(" BOMBS                          ", "white")   ; 215 + 216
    %font2(" FINAL TIME         00'00'00^00 ", "white")   ; 217 + 218
    %font2("       THANKS FOR PLAYING       ", "green")   ; 219 + 220
    dw $dead                              ; End of credits tilemap

warnpc $ceffff

; Placeholder label for item locations inserted by the randomizer
org $ded200
itemlocations:
    %font1("      MAJOR ITEM LOCATIONS      ", "pink") ; 640
    %font1("MORPH BALL                      ", "yellow")
    %font1("................................", "orange")
    %font1("BOMB                            ", "yellow")
    %font1("................................", "orange")
    %font1("CHARGE BEAM                     ", "yellow")
    %font1("................................", "orange")
    %font1("ICE BEAM                        ", "yellow")
    %font1("................................", "orange")
    %font1("WAVE BEAM                       ", "yellow")
    %font1("................................", "orange")
    %font1("SPAZER                          ", "yellow")
    %font1("................................", "orange")
    %font1("PLASMA BEAM                     ", "yellow")
    %font1("................................", "orange")
    %font1("VARIA SUIT                      ", "yellow")
    %font1("................................", "orange")
    %font1("GRAVITY SUIT                    ", "yellow")
    %font1("................................", "orange")
    %font1("HIJUMP BOOTS                    ", "yellow")
    %font1("................................", "orange")
    %font1("SPACE JUMP                      ", "yellow")
    %font1("................................", "orange")
    %font1("SPEED BOOSTER                   ", "yellow")
    %font1("................................", "orange")
    %font1("SCREW ATTACK                    ", "yellow")
    %font1("................................", "orange")
    %font1("SPRING BALL                     ", "yellow")
    %font1("................................", "orange")
    %font1("XRAY SCOPE                      ", "yellow")
    %font1("................................", "orange")
    %font1("GRAPPLING BEAM                  ", "yellow")
    %font1("................................", "orange")
    dd 0
include "../include/snes.asm"
include "tracking.asm"
include "fonts.asm"

// Defines for the script and credits data
define speed = $f770
define set = $9a17
define delay = $9a0d
define draw = $0000
define end = $f6fe, $99fe
define blank = $1fc0
define row = $0040

define last_saveslot = $7fffe0
define timer_backup1 = $7fffe2
define timer_backup2 = $7fffe4
define softreset = $7fffe6
define scroll_speed = $7fffe8

// Patch soft reset to retain value of RTA counter
seek($80844B)
    jml patch_reset1
seek($808490)
    jml patch_reset2

// Patch loading and saving routines
seek($81807f)
    jmp patch_save

seek($8180f7)
    jmp patch_load

// Hijack loading new game to reset stats
seek($828063)
    jsl clear_values

// Hijack the original credits code to read the script from bank $DF
seek($8b9976)
    jml scroll

seek($8b999b)
    jml patch1 

seek($8b99e5)
    jml patch2

seek($8b9a08)
    jml patch3

seek($8b9a19)
    jml patch4



// Hijack when samus is in the ship and ready to leave the planet
seek($a2ab13)
  jsl game_end

// Patch NMI to skip resetting 05ba and instead use that as an extra time counter
seek($8095e5)
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

seek($809602)
    bra nmi_inc
nmi_end:
    ply
    plx
    pla
    pld
    plb
    rti

// Patch soft reset to save the value of the RTA timer
seek($80fe00)
patch_reset1:
    lda {softreset} // Check if we're softresetting
    cmp #$babe
    beq save_timer
    lda #$babe
    sta {softreset}
    lda #$0000
    sta {timer_backup1}
    sta {timer_backup2}
    sta {last_saveslot}
    bra skipsave
save_timer:   
    lda {timer1}
    sta {timer_backup1}
    lda {timer2}
    sta {timer_backup2}
skipsave:
    ldx #$1ffe
    lda #$0000
-
    stz $0000,x
    dex
    dex
    bpl - 
    lda {timer_backup1}
    sta {timer1}
    lda {timer_backup2}
    sta {timer2}
    jml $808455

patch_reset2:
    lda {timer1}
    sta {timer_backup1}
    lda {timer2}
    sta {timer_backup2}
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

    ldx #$00df          // clear temp variables
    lda #$0000
-
    sta $7fff00,x
    dex
    dex
    bpl -

    lda {timer_backup1}
    sta {timer1}
    lda {timer_backup2}
    sta {timer2}
    jml $8084af

warnpc($80ff00)

// Patch load and save routines
seek($81ef20)
patch_save:
    lda {timer1}
    sta $7ffc00
    lda {timer2}
    sta $7ffc02
    jsl save_stats
    lda $7e0952
    clc
    adc #$0010
    sta {last_saveslot}
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
    cmp {last_saveslot}     // If we're loading the same save that's played last
    beq +                   // don't restore stats from SRAM, only do this if
    jsl load_stats          // a new save slot is loaded, or loading from hard reset
    lda $7ffc00
    sta {timer1}
    lda $7ffc02
    sta {timer2}
+
    ply
    plx
    clc
    plb
    rtl

// Hijack after decompression of regular credits tilemaps
seek($8be0d1)
    jsl copy

// Load credits script data from bank $df instead of $8c
seek($8bf770)
set_scroll:
    rep #$30
    phb; pea $df00; plb; plb
    lda $0000,y
    sta {scroll_speed}
    iny
    iny
    plb
    rts

scroll:
    inc $1995
    lda $1995
    cmp {scroll_speed}
    beq +
    lda $1997
    jml $8b9989
+
    stz $1995
    inc $1997
    lda $1997
    jml $8b9989


patch1:
    phb; pea $df00; plb; plb
    lda $0000,y    
    bpl +
    plb
    jml $8b99a0
+
    plb
    jml $8b99aa

patch2:
    sta $0014
    phb; pea $df00; plb; plb
    lda $0002,y    
    plb
    jml $8b99eb

patch3:
    phb; pea $df00; plb; plb
    lda $0000,y
    tay
    plb
    jml $8b9a0c

patch4:
    phb; pea $df00; plb; plb
    lda $0000,y
    plb
    sta $19fb
    jml $8b9a1f

// Copy custom credits tilemap data from $ceb240,x to $7f2000,x
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
    sta {scroll_speed}
    plx
    pla
    jsl $8b95ce
    rtl

clear_values:
    php
    rep #$30
    // Do some checks to see that we're actually starting a new game    
    // Make sure game mode is 1f
    lda $7e0998
    cmp.w #$001f
    bne clear_value_ret
    
    // Check if samus saved energy is 00, if it is, run startup code
    lda $7ed7e2
    bne clear_value_ret

    ldx #$0000
    lda #$0000
-
    jsl store_stat
    inx
    cpx #$0180
    bne -

    // Clear RTA Timer
    lda #$0000
    sta {timer1}
    sta {timer2}

clear_value_ret:
    plp
    jsl $809a79
    rtl

// Game has ended, save RTA timer to RAM and copy all stats to SRAM a final time
function game_end {
  lda {timer1}
  sta $7ffc00
  lda {timer2}
  sta $7ffc02

  // Subtract frames from pressing down at ship to this code running
  lda $7ffc00
  sec
  sbc #$013d
  sta $7ffc00
  lda #$0000  // if carry clear this will subtract one from the high byte of timer
  sbc $7ffc02

  jsl save_stats
  lda #$000a
  jsl $90f084
  rtl
}

seek($dfd4f0)
// Draw full time as hh:mm:ss:ff
// Pointer to first byte of RAM in A
draw_full_time:
    phx
    phb
    pea $7f7f; plb; plb
    tax
    lda $0000,x
    sta $16
    lda $0002,x
    sta $14
    lda #$003c
    sta $12
    lda #$ffff
    sta $1a
    jsr div32 // frames in $14, rest in $16
    iny; iny; iny; iny; iny; iny // Increment Y three positions forward to write the last value    
    lda $14
    jsr draw_two
    tya
    sec
    sbc #$0010
    tay     // Skip back 8 characters to draw the top three things
    lda $16
    jsr draw_time
    plb
    plx
    rts  

// Draw time as xx:yy:zz
draw_time:
    phx
    phb
    dey; dey; dey; dey; dey; dey // Decrement Y by 3 characters so the time count fits
    pea $7f7f; plb; plb
    sta $004204
    sep #$20
    lda #$ff
    sta $1a
    lda #$3c
    sta $004206
    pha; pla; pha; pla; rep #$20
    lda $004216 // Seconds or Frames
    sta $12
    lda $004214 // First two groups (hours/minutes or minutes/seconds)
    sta $004204
    sep #$20
    lda #$3c
    sta $004206
    pha; pla; pha; pla; rep #$20
    lda $004216
    sta $14
    lda $004214 // First group (hours or minutes)
    jsr draw_two
    iny; iny // Skip past separator
    lda $14 // Second group (minutes or seconds)
    jsr draw_two
    iny; iny
    lda $12 // Last group (seconds or frames)
    jsr draw_two
    plb
    plx
    rts        

// Draw 5-digit value to credits tilemap
// A = number to draw, Y = row address
draw_value:
  phx    
  phb
  pea $7f7f; plb; plb
  stz $1a     // Leading zeroes flag

  ldx #100
  jsr integer_division

  lda $004216 // Load the last two digits
  pha         // Push last two digits onto the stack

  lda $004214 // Load the top three digits
  jsr draw_three

  pla         // Pull last two digits from the stack
  jsr draw_two

  plb
  plx
  rts

draw_three:
  ldx #100
  jsr integer_division

  lda $004214 // Hundreds
  jsr draw_digit_without_padding
  iny; iny

  lda $004216
  ldx #10
  jsr integer_division

  lda $004214
  jsr draw_digit_without_padding
  iny; iny

  lda $004216
  jsr draw_digit_without_padding
  iny; iny
  rts

draw_two:
  ldx #10
  jsr integer_division 

  lda $004214
  cmp $1a
  beq +
  jsr draw_digit; +
  iny; iny

  lda $004216
  jsr draw_digit
  iny; iny

  rts

// A = dividend, X = divisor
// $004214 = quotient, $004216 = remainder
integer_division:
  sta $004204
  sep #$20
  txa
  sta $004206
  pha; pla; pha; pla; rep #$20
  rts

draw_digit_without_padding:
  beq +

draw_digit:
  asl
  tax
  lda numbers_top,x
  sta $0034,y
  lda numbers_bot,x
  sta $0074,y; +
  rts

warnpc($dfd635)

seek($dfd635)
// Loop through stat table and update RAM with numbers representing those stats
write_stats:
    phy
    phb
    php
    pea $dfdf; plb; plb
    rep #$30
    jsl load_stats      // Copy stats back from SRAM
    ldx #$0000
    ldy #$0000

write_loop:
    // Get pointer to table
    tya
    asl; asl; asl;
    tax

    // Load stat type
    lda stats+4,x
    beq write_end
    cmp #$0001
    beq write_number
    cmp #$0002
    beq write_time
    cmp #$0003
    beq write_fulltime
    jmp write_continue

write_number:
    // Load statistic
    lda stats,x
    jsl load_stat
    pha

    // Load row address
    lda stats+2,x
    tyx
    tay
    pla
    jsr draw_value
    txy
    jmp write_continue

write_time:
    // Load statistic
    lda stats,x
    jsl load_stat
    pha

    // Load row address
    lda stats+2,x
    tyx
    tay
    pla
    jsr draw_time
    txy
    jmp write_continue

write_fulltime:    
    lda stats,x        // Get stat id
    asl
    clc
    adc #$fc00          // Get pointer to value instead of actual value
    pha

    // Load row address
    lda stats+2,x
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

// 32-bit by 16-bit division routine I found somewhere
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

warnpc($dfd800)

// New credits script in free space of bank $DF
seek($dfd91b)
script:
    dw {set}, $0002; -
    dw {draw}, {blank}
    dw {delay}, -
    
    // Show a compact version of the original credits so we get time to add more    
    dw {draw}, {row}*0      // SUPER METROID STAFF
    dw {draw}, {blank}
    dw {draw}, {row}*4      // PRODUCER
    dw {draw}, {blank}
    dw {draw}, {row}*7      // MAKOTO KANOH
    dw {draw}, {row}*8       
    dw {draw}, {blank}
    dw {draw}, {row}*9      // DIRECTOR
    dw {draw}, {blank}
    dw {draw}, {row}*10     // YOSHI SAKAMOTO
    dw {draw}, {row}*11     
    dw {draw}, {blank}
    dw {draw}, {row}*12     // BACK GROUND DESIGNERS
    dw {draw}, {blank}
    dw {draw}, {row}*13     // HIROFUMI MATSUOKA
    dw {draw}, {row}*14     
    dw {draw}, {blank}
    dw {draw}, {row}*15     // MASAHIKO MASHIMO
    dw {draw}, {row}*16     
    dw {draw}, {blank}
    dw {draw}, {row}*17     // HIROYUKI KIMURA
    dw {draw}, {row}*18     
    dw {draw}, {blank}
    dw {draw}, {row}*19     // OBJECT DESIGNERS
    dw {draw}, {blank}
    dw {draw}, {row}*20     // TOHRU OHSAWA
    dw {draw}, {row}*21     
    dw {draw}, {blank}
    dw {draw}, {row}*22     // TOMOYOSHI YAMANE
    dw {draw}, {row}*23    
    dw {draw}, {blank}
    dw {draw}, {row}*24     // SAMUS ORIGINAL DESIGNERS
    dw {draw}, {blank}
    dw {draw}, {row}*25     // HIROJI KIYOTAKE
    dw {draw}, {row}*26    
    dw {draw}, {blank}
    dw {draw}, {row}*27     // SAMUS DESIGNER
    dw {draw}, {blank}
    dw {draw}, {row}*28     // TOMOMI YAMANE
    dw {draw}, {row}*29    
    dw {draw}, {blank}
    dw {draw}, {row}*83     // SOUND PROGRAM
    dw {draw}, {row}*107    // AND SOUND EFFECTS
    dw {draw}, {blank}
    dw {draw}, {row}*84     // KENJI YAMAMOTO
    dw {draw}, {row}*85    
    dw {draw}, {blank}
    dw {draw}, {row}*86     // MUSIC COMPOSERS
    dw {draw}, {blank}
    dw {draw}, {row}*84     // KENJI YAMAMOTO
    dw {draw}, {row}*85    
    dw {draw}, {blank}
    dw {draw}, {row}*87     // MINAKO HAMANO
    dw {draw}, {row}*88    
    dw {draw}, {blank}
    dw {draw}, {row}*30     // PROGRAM DIRECTOR
    dw {draw}, {blank}
    dw {draw}, {row}*31     // KENJI IMAI
    dw {draw}, {row}*64    
    dw {draw}, {blank}
    dw {draw}, {row}*65     // SYSTEM COORDINATOR
    dw {draw}, {blank}
    dw {draw}, {row}*66     // KENJI NAKAJIMA
    dw {draw}, {row}*67    
    dw {draw}, {blank}
    dw {draw}, {row}*68     // SYSTEM PROGRAMMER
    dw {draw}, {blank}
    dw {draw}, {row}*69     // YOSHIKAZU MORI
    dw {draw}, {row}*70    
    dw {draw}, {blank}
    dw {draw}, {row}*71     // SAMUS PROGRAMMER
    dw {draw}, {blank}
    dw {draw}, {row}*72     // ISAMU KUBOTA
    dw {draw}, {row}*73    
    dw {draw}, {blank}
    dw {draw}, {row}*74     // EVENT PROGRAMMER
    dw {draw}, {blank}
    dw {draw}, {row}*75     // MUTSURU MATSUMOTO
    dw {draw}, {row}*76    
    dw {draw}, {blank}
    dw {draw}, {row}*77     // ENEMY PROGRAMMER
    dw {draw}, {blank}
    dw {draw}, {row}*78     // YASUHIKO FUJI
    dw {draw}, {row}*79    
    dw {draw}, {blank}
    dw {draw}, {row}*80     // MAP PROGRAMMER
    dw {draw}, {blank}
    dw {draw}, {row}*81     // MOTOMU CHIKARAISHI
    dw {draw}, {row}*82    
    dw {draw}, {blank}
    dw {draw}, {row}*101    // ASSISTANT PROGRAMMER
    dw {draw}, {blank}
    dw {draw}, {row}*102    // KOUICHI ABE
    dw {draw}, {row}*103   
    dw {draw}, {blank}
    dw {draw}, {row}*104    // COORDINATORS
    dw {draw}, {blank}
    dw {draw}, {row}*105    // KATSUYA YAMANO
    dw {draw}, {row}*106   
    dw {draw}, {blank}
    dw {draw}, {row}*63     // TSUTOMU KANESHIGE
    dw {draw}, {row}*96   
    dw {draw}, {blank}
    dw {draw}, {row}*89    // PRINTED ART WORK
    dw {draw}, {blank}
    dw {draw}, {row}*90    // MASAFUMI SAKASHITA
    dw {draw}, {row}*91   
    dw {draw}, {blank}
    dw {draw}, {row}*92    // YASUO INOUE
    dw {draw}, {row}*93   
    dw {draw}, {blank}
    dw {draw}, {row}*94    // MARY COCOMA
    dw {draw}, {row}*95   
    dw {draw}, {blank}
    dw {draw}, {row}*99    // YUSUKE NAKANO
    dw {draw}, {row}*100   
    dw {draw}, {blank}
    dw {draw}, {row}*108   // SHINYA SANO
    dw {draw}, {row}*109   
    dw {draw}, {blank}
    dw {draw}, {row}*110   // NORIYUKI SATO
    dw {draw}, {row}*111   
    dw {draw}, {blank}
    dw {draw}, {row}*32    // SPECIAL THANKS TO
    dw {draw}, {blank}
    dw {draw}, {row}*33    // DAN OWSEN
    dw {draw}, {row}*34   
    dw {draw}, {blank}
    dw {draw}, {row}*35    // GEORGE SINFIELD
    dw {draw}, {row}*36   
    dw {draw}, {blank}
    dw {draw}, {row}*39    // MASARU OKADA
    dw {draw}, {row}*40   
    dw {draw}, {blank}
    dw {draw}, {row}*43    // TAKAHIRO HARADA
    dw {draw}, {row}*44   
    dw {draw}, {blank}
    dw {draw}, {row}*47    // KOHTA FUKUI
    dw {draw}, {row}*48   
    dw {draw}, {blank}
    dw {draw}, {row}*49    // KEISUKE TERASAKI
    dw {draw}, {row}*50   
    dw {draw}, {blank}
    dw {draw}, {row}*51    // MASARU YAMANAKA
    dw {draw}, {row}*52   
    dw {draw}, {blank}
    dw {draw}, {row}*53    // HITOSHI YAMAGAMI
    dw {draw}, {row}*54   
    dw {draw}, {blank}
    dw {draw}, {row}*57    // NOBUHIRO OZAKI
    dw {draw}, {row}*58   
    dw {draw}, {blank}
    dw {draw}, {row}*59    // KENICHI NAKAMURA
    dw {draw}, {row}*60   
    dw {draw}, {blank}
    dw {draw}, {row}*61    // TAKEHIKO HOSOKAWA
    dw {draw}, {row}*62   
    dw {draw}, {blank}
    dw {draw}, {row}*97    // SATOSHI MATSUMURA
    dw {draw}, {row}*98   
    dw {draw}, {blank}
    dw {draw}, {row}*122   // TAKESHI NAGAREDA
    dw {draw}, {row}*123  
    dw {draw}, {blank}
    dw {draw}, {row}*124   // MASAHIRO KAWANO
    dw {draw}, {row}*125  
    dw {draw}, {blank}
    dw {draw}, {row}*45    // HIRO YAMADA
    dw {draw}, {row}*46  
    dw {draw}, {blank}
    dw {draw}, {row}*112   // AND ALL OF R&D1 STAFFS
    dw {draw}, {row}*113  
    dw {draw}, {blank}
    dw {draw}, {row}*114   // GENERAL MANAGER
    dw {draw}, {blank}
    dw {draw}, {row}*5     // GUMPEI YOKOI
    dw {draw}, {row}*6  
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {blank}

    // Custom item randomizer credits text        

    dw {draw}, {row}*128  // Randomizer staff
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {row}*163  // Game balance
    dw {draw}, {blank}
    dw {draw}, {row}*165  // kipp
    dw {draw}, {row}*166
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {row}*129  // Rando code
    dw {draw}, {blank}
    dw {draw}, {row}*130  // total
    dw {draw}, {row}*131
    dw {draw}, {blank}
    dw {draw}, {row}*132  // dessyreqt
    dw {draw}, {row}*133
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {row}*141  // ROM patches
    dw {draw}, {blank}
    dw {draw}, {row}*137  // andreww
    dw {draw}, {row}*138
    dw {draw}, {blank}
    dw {draw}, {row}*146  // leodox
    dw {draw}, {row}*147
    dw {draw}, {blank}
    dw {draw}, {row}*139  // personitis
    dw {draw}, {row}*140
    dw {draw}, {blank}
    dw {draw}, {row}*142  // smiley
    dw {draw}, {row}*143
    dw {draw}, {blank}
    dw {draw}, {row}*130  // total
    dw {draw}, {row}*131
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {row}*162  // Logo design
    dw {draw}, {blank}
    dw {draw}, {row}*160  // minimemys
    dw {draw}, {row}*161
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {row}*157  // Technical Support
    dw {draw}, {blank}
    dw {draw}, {row}*158  // masshesteria
    dw {draw}, {row}*159
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {row}*148  // Special thanks to
    dw {draw}, {blank}
    dw {draw}, {row}*154  // Testers
    dw {draw}, {blank}
    dw {draw}, {row}*137  // andreww
    dw {draw}, {row}*138
    dw {draw}, {blank}
    dw {draw}, {row}*155  // fbs
    dw {draw}, {row}*156
    dw {draw}, {blank}
    dw {draw}, {row}*171  // maniacal
    dw {draw}, {row}*172
    dw {draw}, {blank}
    dw {draw}, {row}*173  // osse
    dw {draw}, {row}*174
    dw {draw}, {blank}
    dw {draw}, {row}*135  // rumble
    dw {draw}, {row}*136
    dw {draw}, {blank}
    dw {draw}, {row}*144  // sloaters
    dw {draw}, {row}*145
    dw {draw}, {blank}
    dw {draw}, {row}*167  // tracie
    dw {draw}, {row}*168
    dw {draw}, {blank}
    dw {draw}, {row}*169  // zeb
    dw {draw}, {row}*170
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {row}*149  // Disassembly
    dw {draw}, {blank}
    dw {draw}, {row}*150
    dw {draw}, {row}*151
    dw {draw}, {blank}
    dw {draw}, {row}*152
    dw {draw}, {row}*153
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {row}*175  // Metroid construction
    dw {draw}, {blank}
    dw {draw}, {row}*176
    dw {draw}, {row}*177
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {row}*178  // SRL
    dw {draw}, {blank}
    dw {draw}, {row}*179
    dw {draw}, {row}*180
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {row}*164  // Play this randomizer at
    dw {draw}, {blank}
    dw {draw}, {row}*181
    dw {draw}, {row}*182
    dw {draw}, {blank}
    
    dw {draw}, {blank}
    dw {draw}, {row}*183  // Game play stats
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {row}*184  // Doors
    dw {draw}, {blank}

    // Set scroll speed to 3 frames per pixel
    dw {speed}, $0003
    dw {draw}, {row}*185
    dw {draw}, {row}*186
    dw {draw}, {blank}
    dw {draw}, {row}*187
    dw {draw}, {row}*188
    dw {draw}, {blank}
    dw {draw}, {row}*189
    dw {draw}, {row}*190
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {row}*191
    dw {draw}, {blank}
    dw {draw}, {row}*192
    dw {draw}, {row}*193
    dw {draw}, {blank}
    dw {draw}, {row}*194
    dw {draw}, {row}*195
    dw {draw}, {blank}
    dw {draw}, {row}*196
    dw {draw}, {row}*197
    dw {draw}, {blank}
    dw {draw}, {row}*198
    dw {draw}, {row}*199
    dw {draw}, {blank}
    dw {draw}, {row}*200
    dw {draw}, {row}*201
    dw {draw}, {blank}
    dw {draw}, {row}*202
    dw {draw}, {row}*203
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {row}*204
    dw {draw}, {blank}
    dw {draw}, {row}*205
    dw {draw}, {row}*206
    dw {draw}, {blank}
    dw {draw}, {row}*207
    dw {draw}, {row}*208
    dw {draw}, {blank}
    dw {draw}, {row}*209
    dw {draw}, {row}*210
    dw {draw}, {blank}
    dw {draw}, {row}*211
    dw {draw}, {row}*212
    dw {draw}, {blank}
    dw {draw}, {row}*213
    dw {draw}, {row}*214
    dw {draw}, {blank}
    dw {draw}, {row}*215
    dw {draw}, {row}*216

   
    // Draw item locations
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {row}*640
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {row}*641
    dw {draw}, {row}*642
    dw {draw}, {blank}
    dw {draw}, {row}*643
    dw {draw}, {row}*644
    dw {draw}, {blank}
    dw {draw}, {row}*645
    dw {draw}, {row}*646
    dw {draw}, {blank}
    dw {draw}, {row}*647
    dw {draw}, {row}*648
    dw {draw}, {blank}
    dw {draw}, {row}*649
    dw {draw}, {row}*650
    dw {draw}, {blank}
    dw {draw}, {row}*651
    dw {draw}, {row}*652
    dw {draw}, {blank}
    dw {draw}, {row}*653
    dw {draw}, {row}*654
    dw {draw}, {blank}
    dw {draw}, {row}*655
    dw {draw}, {row}*656
    dw {draw}, {blank}
    dw {draw}, {row}*657
    dw {draw}, {row}*658
    dw {draw}, {blank}
    dw {draw}, {row}*659
    dw {draw}, {row}*660
    dw {draw}, {blank}
    dw {draw}, {row}*661
    dw {draw}, {row}*662
    dw {draw}, {blank}
    dw {draw}, {row}*663
    dw {draw}, {row}*664
    dw {draw}, {blank}
    dw {draw}, {row}*665
    dw {draw}, {row}*666
    dw {draw}, {blank}
    dw {draw}, {row}*667
    dw {draw}, {row}*668
    dw {draw}, {blank}
    dw {draw}, {row}*669
    dw {draw}, {row}*670
    dw {draw}, {blank}
    dw {draw}, {row}*671
    dw {draw}, {row}*672

    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {row}*217
    dw {draw}, {row}*218
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {row}*219
    dw {draw}, {row}*220        
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {blank}
    dw {draw}, {blank}

    // Set scroll speed to 4 frames per pixel
    dw {speed}, $0004
   
    // Scroll all text off and end credits
    dw {set}, $0017; -
    dw {draw}, {blank}
    dw {delay}, -    
    dw {end}

stats:
    // STAT ID, ADDRESS,    TYPE (1 = Number, 2 = Time, 3 = Full time), UNUSED
    dw 0,       {row}*217,  3, 0    // Full RTA Time
    dw 2,       {row}*185,  1, 0    // Door transitions
    dw 3,       {row}*187,  3, 0    // Time in doors
    dw 5,       {row}*189,  2, 0    // Time adjusting doors
    dw 7,       {row}*192,  3, 0    // Crateria
    dw 9,       {row}*194,  3, 0    // Brinstar
    dw 11,      {row}*196,  3, 0    // Norfair
    dw 13,      {row}*198,  3, 0    // Wrecked Ship
    dw 15,      {row}*200,  3, 0    // Maridia
    dw 17,      {row}*202,  3, 0    // Tourian
    dw 20,      {row}*205,  1, 0    // Charged Shots
    dw 21,      {row}*207,  1, 0    // Special Beam Attacks
    dw 22,      {row}*209,  1, 0    // Missiles
    dw 23,      {row}*211,  1, 0    // Super Missiles
    dw 24,      {row}*213,  1, 0    // Power Bombs
    dw 26,      {row}*215,  1, 0    // Bombs
    dw 0,               0,  0, 0    // end of table

warnpc($dfffff)

// Relocated credits tilemap to free space in bank CE
seek($ceb240)
credits:
    // Single line characters:
    //   ABCDEFGHIJKLMNOPQRSTUVWXYZ.,':!
    // Double line characters:
    //   ABCDEFGHIJKLMNOPQRSTUVWXYZ.^':%&
    //   0123456789
    
    font1("     DASH RANDOMIZER STAFF      ", {pink})    // 128
    font1("        RANDOMIZER CODE         ", {purple})  // 129
    font2("             TOTAL              ", {white})   // 130 + 131
    font2("           DESSYREQT            ", {white})   // 132 + 133
    font1("           SNES CODE            ", {purple})  // 134
    font2("          RUMBLEMINZE           ", {white})   // 135 + 136
    font2("            ANDREWW             ", {white})   // 137 + 138
    font2("           PERSONITIS           ", {white})   // 139 + 140
    font1("          ROM PATCHES           ", {purple})  // 141
    font2("             SMILEY             ", {white})   // 142 + 143
    font2("           SLOATERS27           ", {white})   // 144 + 145
    font2("             LEODOX             ", {white})   // 146 + 147
    font1("       SPECIAL THANKS TO        ", {cyan})    // 148
    font1("   SUPER METROID DISASSEMBLY    ", {yellow})  // 149
    font2("             PJBOY              ", {white})   // 150 + 151
    font2("            KEJARDON            ", {white})   // 152 + 153
    font1("            TESTERS             ", {yellow})  // 154
    font2("         FRUITBATSALAD          ", {white})   // 155 + 156
    font1("       TECHNICAL SUPPORT        ", {purple})  // 157
    font2("          MASSHESTERIA          ", {white})   // 158 + 159
    font2("           MINIMEMYS            ", {white})   // 160 + 161
    font1("          LOGO DESIGN           ", {purple})  // 162
    font1("          GAME BALANCE          ", {purple})  // 163
    font1("     PLAY THIS RANDOMIZER AT    ", {cyan})    // 164
    font2("              KIPP              ", {white})   // 165 + 166
    font2("            TRACIEM             ", {white})   // 167 + 168
    font2("             ZEB316             ", {white})   // 169 + 170
    font2("           MANIACAL42           ", {white})   // 171 + 172
    font2("            OSSE101             ", {white})   // 173 + 174
    font1("      METROID CONSTRUCTION      ", {yellow})  // 175
    font2("     METROIDCONSTRUCTION.COM    ", {white})   // 176 + 177
    font1("  SUPER METROID SRL COMMUNITY   ", {yellow})  // 178
    font2("    DISCORD INVITE : 6RYJM4M    ", {white})   // 179 + 180
    font2("      DASHRANDO.GITHUB.IO       ", {white})   // 181 + 182
    font1("      GAMEPLAY STATISTICS       ", {purple})  // 183
    font1("             DOORS              ", {orange})  // 184
    font2(" DOOR TRANSITIONS               ", {white})   // 185 + 186
    font2(" TIME IN DOORS      00'00'00^00 ", {white})   // 187 + 188
    font2(" TIME ALIGNING DOORS   00'00^00 ", {white})   // 189 + 190
    font1("         TIME SPENT IN          ", {blue})    // 191
    font2(" CRATERIA           00'00'00^00 ", {white})   // 192 + 193
    font2(" BRINSTAR           00'00'00^00 ", {white})   // 194 + 195
    font2(" NORFAIR            00'00'00^00 ", {white})   // 196 + 197
    font2(" WRECKED SHIP       00'00'00^00 ", {white})   // 198 + 199
    font2(" MARIDIA            00'00'00^00 ", {white})   // 200 + 201
    font2(" TOURIAN            00'00'00^00 ", {white})   // 202 + 203
    font1("      SHOTS AND AMMO FIRED      ", {green})   // 204
    font2(" CHARGED SHOTS                  ", {white})   // 205 + 206
    font2(" SPECIAL BEAM ATTACKS           ", {white})   // 207 + 208
    font2(" MISSILES                       ", {white})   // 209 + 210
    font2(" SUPER MISSILES                 ", {white})   // 211 + 212
    font2(" POWER BOMBS                    ", {white})   // 213 + 214
    font2(" BOMBS                          ", {white})   // 215 + 216
    font2(" FINAL TIME         00'00'00^00 ", {white})   // 217 + 218
    font2("       THANKS FOR PLAYING       ", {green})   // 219 + 220
    dw $dead                              // End of credits tilemap

warnpc($ceffff)

// Placeholder label for item locations inserted by the randomizer
seek($ded200)
itemlocations:
    font1("      MAJOR ITEM LOCATIONS      ", {pink}) // 640
    font1("MORPH BALL                      ", {yellow})
    font1("................................", {orange})
    font1("BOMB                            ", {yellow})
    font1("................................", {orange})
    font1("CHARGE BEAM                     ", {yellow})
    font1("................................", {orange})
    font1("ICE BEAM                        ", {yellow})
    font1("................................", {orange})
    font1("WAVE BEAM                       ", {yellow})
    font1("................................", {orange})
    font1("SPAZER                          ", {yellow})
    font1("................................", {orange})
    font1("PLASMA BEAM                     ", {yellow})
    font1("................................", {orange})
    font1("VARIA SUIT                      ", {yellow})
    font1("................................", {orange})
    font1("GRAVITY SUIT                    ", {yellow})
    font1("................................", {orange})
    font1("HIJUMP BOOTS                    ", {yellow})
    font1("................................", {orange})
    font1("SPACE JUMP                      ", {yellow})
    font1("................................", {orange})
    font1("SPEED BOOSTER                   ", {yellow})
    font1("................................", {orange})
    font1("SCREW ATTACK                    ", {yellow})
    font1("................................", {orange})
    font1("SPRING BALL                     ", {yellow})
    font1("................................", {orange})
    font1("XRAY SCOPE                      ", {yellow})
    font1("................................", {orange})
    font1("GRAPPLING BEAM                  ", {yellow})
    font1("................................", {orange})
    dd 0
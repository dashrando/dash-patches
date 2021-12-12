// RTA Timer (timer 1 is frames, and timer 2 is number of times frames rolled over)
define timer1 = $05b8
define timer2 = $05ba

// Temp variables (define here to make sure they're not reused, make sure they're 2 bytes apart)
// These variables are cleared to 0x00 on hard and soft reset
define door_timer_tmp = $7fff00
define door_adjust_tmp = $7fff02
define add_time_tmp = $7fff04
define region_timer_tmp = $7fff06
define region_tmp = $7fff08

// -------------------------------
// HIJACKS
// -------------------------------

// Samus hit a door block (Gamestate change to $09 just before hitting $0a)
seek($82e176)
  jml door_entered

// Samus gains control back after door (Gamestate change back to $08 after door transition)
seek($82e764)
  jml door_exited

// Door starts adjusting
seek($82e309)
  jml door_adjust_start

// Door stops adjusting
seek($82e34c)
  jml door_adjust_stop

// Firing charged beam
seek($90b9a1)
  jml charged_beam

// Firing SBAs
seek($90ccde)
  jmp fire_sba_local	

//Missiles/supers fired
seek($90beb7)
  jml missiles_fired

//Bombs/PBs laid
seek($90c107)
  jml bombs_laid

seek($90f800)
fire_sba_local:
  jml fire_sba

// -------------------------------
// FUNCTIONS
// -------------------------------

// Increment Statistic (A = ID of statistic)
seek($dfd800)
function inc_stat {
  phx
  asl
  tax
  lda $7ffc00,x
  inc
  sta $7ffc00,x
  plx
  rtl
}

// Decrement Statistic (A = ID of statistic)
seek($dfd840)
function dec_stat {
  phx
  asl
  tax
  lda $7ffc00,x
  dec
  sta $7ffc00,x
  plx
  rtl
}

// Store Statistic (value in A, stat in X)
seek($dfd880)
function store_stat {
  phx
  pha
  txa
  asl
  tax
  pla
  sta $7ffc00,x
  plx
  rtl
}

// Load Statistic (stat in A, returns value in A)
seek($dfd8b0)
function load_stat {
  phx
  asl
  tax
  lda $7ffc00,x
  plx
  rtl
}

// -------------------------------
// CODE (using bank A1 free space)
// -------------------------------
seek($a1ec00)
// Helper function to add a time delta, X = stat to add to, A = value to check against
// This uses 4-bytes for each time delta
function add_time {
  sta {add_time_tmp}
  lda {timer1}
  sec
  sbc {add_time_tmp}
  sta {add_time_tmp}
  txa
  jsl load_stat
  clc
  adc {add_time_tmp}
  bcc +
  jsl store_stat    // If carry set, increase the high bits
  inx
  txa
  jsl inc_stat; +
  jsl store_stat
  rts
}

// Samus hit a door block (Gamestate change to $09 just before hitting $0a)
function door_entered {
  lda #$0002  // Number of door transitions
  jsl inc_stat

  lda {timer1}
  sta {door_timer_tmp} // Save RTA time to temp variable

  // Run hijacked code and return
  plp
  inc $0998
  jml $82e1b7
}

// Samus gains control back after door (Gamestate change back to $08 after door transition)
function door_exited {

  // Increment saved value with time spent in door transition
  lda {door_timer_tmp}
  ldx #$0003
  jsr add_time

  // Store time spent in last room/area unless region_tmp is 0
  lda {region_tmp}
  beq +
  tax
  lda {region_timer_tmp}
  jsr add_time; +
    
  // Store the current frame and the current region to temp variables
  lda {timer1}
  sta {region_timer_tmp}
  lda $7e079f
  asl
  clc
  adc #$0007    
  sta {region_tmp}    // Store (region*2) + 7 to region_tmp (This uses stat id 7-18 for region timers)

  // Run hijacked code and return
  lda #$0008
  sta $0998
  jml $82e76a
}

// Door adjust start
function door_adjust_start {
  lda {timer1}
  sta {door_adjust_tmp} // Save RTA time to temp variable

  // Run hijacked code and return
  lda #$e310
  sta $099c
  jml $82e30f
}

// Door adjust stop
function door_adjust_stop {
  lda {door_adjust_tmp}
  inc // Add extra frame to time delta so that perfect doors counts as 0
  ldx #$0005
  jsr add_time

  // Run hijacked code and return
  lda #$e353
  sta $099c
  jml $82e352
}

// Charged Beam Fire
function charged_beam {
  lda #$0014
  jsl inc_stat

  // Run hijacked code and return
  ldx #$0000
  lda $0c2c,x
  jml $90b9a7
}

// Firing SBAs : hijack the point where new qty of PBs is stored
function fire_sba {
  // check if SBA routine actually changed PB count: means valid beam combo selected
  cmp $09ce
  beq +
  pha
  lda #$0015
  jsl inc_stat
  pla
+ // Run hijacked code and return
  sta $09ce
  jml $90cce1
}

// Missile or Super Missile Fired
function missiles_fired {

  // Check to see if Supers are selected on HUD
  lda $09d2
  cmp #$0002
  beq super_missile

regular_missile:
  dec $09c6
  lda #$0016
  jsl inc_stat
  bra +

super_missile:
  dec $09ca
  lda #$0017
  jsl inc_stat

+ // Return
  jml $90bec7
}

// Bomb or Power Bomb Laid
function bombs_laid {

  // Check to see if PBs are selected on HUD
  lda $09d2
  cmp #$0003
  beq power_bomb

regular_bomb:
  lda #$001a
  bra +

power_bomb:
  lda #$0018

+ // Increment stat, run hijacked code and return
  jsl inc_stat
  lda $0cd2
  inc
  jml $90c10b
}
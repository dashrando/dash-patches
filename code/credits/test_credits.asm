include "../include/snes.asm"

constant DoorTransitions = $0002
constant ChargeShots = $0014
constant SpecialBeamAttacks = $0015
constant SuperMissiles = $0016
constant Missiles = $0017
constant PowerBombs = $0018

macro set_stat(define stat, define value) {
  ldx #{stat}
  lda {value}
  jsl $dfd880
}

macro set_all_stats() {
  phx
  set_stat(DoorTransitions, #555)
  set_stat(ChargeShots, #12345)
  set_stat(SpecialBeamAttacks, #6789)
  set_stat(SuperMissiles, #123)
  set_stat(Missiles, #45)
  set_stat(PowerBombs, #6)
  plx
}

seek($82eeda)
db $1f

// ****************
// As gameplay starts, a number of routines are called starting at $82805F
//
// JSL $80A07B (Start gameplay)
// JSL $809A79 (Initialize HUD)
// JSL $A09784 (Does nothing, simply calls RTL)
//
// Because the routine at $A09784 simply returns, it is a perfect opportunity
// to inject our own initialization routine at $828067
// ****************
seek($828067)
jsl introskip

seek($80ff00)
introskip:
lda $7e0998
cmp.w #$001f
bne ret

// Check if samus saved energy is 00, if it is, run startup code
lda $7ed7e2
bne ret
    
// Set construction zone and red tower elevator doors to blue
lda $7ed8b6       // 4
ora.w #$0004      // 3
sta $7ed8b6       // 4

// 
//lda $7ed8b2       // 4
//ora.w #$0001      // 3
//sta $7ed8b2       // 4

// Call the save code to create a new file
//lda $7e0952       // 4
//jsl $818000       // 4

lda #$000e         // 3
jsl $80818e        // 4
lda $7ed820,x      // 4
ora $05e7          // 3
sta $7ed820,x      // 4

set_all_stats()

ret:
lda #$0000
rtl

warnpc($80ffC0)
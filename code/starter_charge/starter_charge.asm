; Original version by Smiley
; Reworked by MassHesteria

; HUD Handler
org $90B821
BRA $0A

; Fire Uncharged Beam
org $90B8F2
BRA $28

; Charge Shot Damage Logic
org $90B9E2

; Hijack the call to initialize the projectile
  JSL $93F61D

org $93F61D
; Initialize projectile
  JSL $938000

; Check if charge is equipped
  LDA $09A6
  BIT #$1000
  BNE +

; Swap data banks
  PHP
  PHB
  PHK
  PLB
  REP #$30
  
; Lookup the uncharged damage value ($93800F)
  LDA $0C18,x   ; Load projectile type into A
  AND #$000F    ; Drop all but last 4 bits
  ASL           ; Double A
  TAY           ; Move A to Y
  LDA $83C1,y   ; Load address of damage into A
  TAY           ; Move A to Y
  LDA $0000,y   ; Load damage into A
  STA $0C2C,x   ; Store final damage
  
; Restore the previous data bank and return
  PLB
  PLP
+ RTL
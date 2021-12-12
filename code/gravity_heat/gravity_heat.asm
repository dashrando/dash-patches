; Original version by Smiley
; Reworked by MassHesteria

;Gravity Suit no longer nullfies heat damage
org $8DE37D : DB $01

; Overwrite portion of suit division routine
org $90E9DC
; Mask equipped items to only Gravity (20) and Varia (01)
  AND #$0021
; Perform no division if neither is equipped
  BEQ $30
; Check to see if both are equipped
  CMP #$0021
; Go to "dmg/4" for both, fall into "dmg/2" for one
  BEQ $16
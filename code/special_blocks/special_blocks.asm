; Written by Smiley

;;;Breakable block - breaks to regular bombs, speedbooster, shinespark and screw attack;;;
;Use a bomb block (tiletype F) with BTS 08
namespace "SpecialSpeedBlock"
!bts = $08 ;Maximum 0F

org $94936B ;Samus runs into block reaction
SamusCollideReaction:
skip 2*!bts
  dw .CollidePLM
org $84D010 ;Overwrite unused PLM header
.CollidePLM
  dw .Init, $CCE3
org $84D409 ;Overwrite unused code
.Init
   LDA $0B3E : CMP #$03FF : BPL +                        ;If speedboosting
   LDA $0A1C : CMP #$0081 : BEQ ++ : CMP #$0082 : BEQ ++ ;Or not using screw attack
+  JMP $CE83                                             ;Behave like a regular bomb block
++ LDA #$0000 : STA $1C37,y ;Else delete PLM
   SEC : RTS

org $94A012 ;Projectile/bomb reaction
ProjectileReaction:
skip 2*!bts
  dw .ShotPLM
org $84D00C ;Overwrite unused PLM header
.ShotPLM
  dw .Init, $CCEA
org $84D42B ;Overwrite unused code
.Init
  LDX $0DDE : LDA $0C18,x : AND #$0F00 : CMP #$0500 : BNE + : JMP $CF0C ;If regular bomb, break
+ LDA #$0000 : STA $1C37,y ;Else delete PLM
  RTS
namespace off


  
;;;Breakable block 2 - breaks to speedbooster, or a beam containing Spazer;;;
;Use a bomb block (tiletype F) with BTS 09
namespace "SpecialShotBlock"
!bts2 = $09 ;Maximum 0F

org $94936B ;Samus runs into block reaction
SamusCollideReaction:
skip 2*!bts2
  dw $D040 ;Speedbooster tile (non-respawning)


org $94A012 ;Projectile/bomb reaction
ProjectileReaction:
skip 2*!bts2
  dw .ShotPLM
org $84D014 ;Overwrite unused PLM header
.ShotPLM
  dw .Init, $CBB7
org $84D443 ;Overwrite unused code
.Init
  LDX $0DDE : LDA $0C18,x : BIT #$0004 : BEQ + : JMP $CF0C ;If projectile is Spazer (or any combo incl. spazer), break
+ LDA #$0000 : STA $1C37,y ;Else delete PLM
  RTS
namespace off
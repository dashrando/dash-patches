; Written by Smiley

; -- Modified suit damage from Enemies -- ;

org $A0A45E ;Enemies
	STA $12
	LDA $09A2 ;A = equipped items
	BIT #$0001 : BEQ + : LSR $12 ;If Varia equipped, damage /= 2
+	BIT #$0020 : BEQ + : LSR $12 ;If Gravity equipped, damage /= 2
+	LDA $12				;A = final damage
	RTL
	
; -- Modified suit damage from Metroids -- ;

org $A3EED8 ;Metroid damage
  LDA #$C000 : STA $12 ;Base
  LDA $09A2 : BIT #$0020 : BEQ + : LSR $12 ;If gravity equipped, damage /= 2
+ BIT #$0001 : BEQ + : LSR $12 ;If Varia equipped, damage /= 2
+ JMP $EEF2
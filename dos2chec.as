; dos2chec.as - MSX-DOS version detection (relocatable module)

; Self-contained. No include needed, so it drops into any program.

		.z80

		global	dos2check

BDOS		equ	00005h
_DOSVER		equ	0006fh		; BDOS function: get MSX-DOS version

		cseg

; dos2check - detect whether we're running under MSX-DOS2
; In:		nothing
; Out:		A  = MSX-DOS major version (1 = DOS1, 2+ = DOS2)
;		CY = set if *NOT* DOS2, clear if DOS2, so the caller can branch
;		with "jr c,..."
; Modifies:	AF, BC, DE, HL

dos2check:	ld	b, 1		; sentinel
		ld	c,_DOSVER
		call	BDOS		; DOS2 -> B = major version
					; DOS1 -> B untouched
		ld	a,b
		cp	2
		ret	nc		; A >= 2 -> DOS2: carry clear
		scf			; A <  2 -> DOS1: set carry
		ret

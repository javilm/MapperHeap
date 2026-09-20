; meminfo.as - MapperHeap example 1: how much mapper RAM is in this machine?
;
; The smallest possible MapperHeap program. It starts the library and asks
; MSX-DOS2, through maptot, how many 16K segments of mapper RAM it is
; managing, then prints that in segments and in kilobytes. It allocates
; nothing at all.
;
; Shows:  heapinit, maptot, p2restore.
; Build:  see make.bat

		.z80

		include	dos2func.inc	; MSX-DOS function numbers
		include	alloc.inc	; the MapperHeap routines
		include	farptr.inc	; far-pointer macros + NULLOFF

		external dos2check	; in dos2chec.as
		external bin2dec16	; in bin2str.as

BDOS		equ	00005h		; dos2func.inc gives the function
					; numbers, not this entry address

system		macro	func
		ld	c,func
		call	BDOS
		endm

		cseg

main:		call	dos2check	; MSX-DOS2?
		jp	c,main.nodos2	; CY = no, this is MSX-DOS1

		call	heapinit	; mapper access + an empty heap
		jp	c,main.nomap	; CY = no mapper support

		call	maptot		; HL = total number of 16K segments
		ld	(segs),hl

		ld	ix,num_seg	; print it as a segment count
		ld	e," "
		call	bin2dec16

		ld	hl,(segs)	; KB = segments * 16
		add	hl,hl		; x2
		add	hl,hl		; x4
		add	hl,hl		; x8
		add	hl,hl		; x16
		ld	ix,num_kb
		ld	e," "
		call	bin2dec16

		call	p2restore	; page 2 back to MSX-DOS before BDOS
		ld	de,report
		system	_STROUT
		system	_TERM0

main.nodos2:	ld	de,msg_dos1
		jr	main.abort
main.nomap:	ld	de,msg_nomap
main.abort:	push	de		; p2restore modifies DE, so the message
		call	p2restore	;   address has to be saved across it.
		pop	de		;   (p2restore is safe even before heapinit)
		system	_STROUT
		system	_TERM0

		dseg

segs:		defs	2		; the count maptot returned

report:		defb	"Mapper RAM: "
num_seg:	defs	5
		defb	" segments ("
num_kb:		defs	5
		defb	" KB)",13,10,"$"

msg_dos1:	defb	"This program needs MSX-DOS2.",13,10,"$"
msg_nomap:	defb	"No memory mapper found.",13,10,"$"

		end

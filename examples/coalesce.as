; coalesce.as - MapperHeap example 5: watch two freed blocks merge.
;
; When a block is freed, MapperHeap joins it to any free block physically next
; to it in the same segment. This program makes that visible.
;
; It allocates three 4000-byte blocks, A, B and C. Blocks are taken from the
; end of the free space, so in memory they come out in this order, with the
; unused remainder of the segment at the bottom:
;
;       offset 0004h  [ free, what is left of the segment ]
;                     [ C ]
;                     [ B ]
;                     [ A ]
;       offset 3FFCh  [ end marker ]
;
; A and B are then freed. They touch, so they merge into one free block of
; 8008 bytes that starts exactly where B started. A request for 8000 bytes is
; then made: 8004 bytes are needed for it, the merged block is the first one
; on the free list, and the 4 bytes left over are below the 12-byte minimum,
; so the whole merged block is taken. The new block's far pointer should
; therefore be identical to the one B had.
;
; The program prints A's, B's and the new block's far pointers, and says
; whether the new one matches B.
;
; This only works from a heap that is completely empty, which is why the
; program does its three allocations first thing.
;
; Shows:  merging on free, first-fit allocation, how to print a far pointer.
; Build:  see make.bat

		.z80

		include	dos2func.inc
		include	alloc.inc
		include	farptr.inc

		external dos2check	; in dos2chec.as
		external bin2dec8	; in bin2str.as
		external bin2hex16	; in bin2str.as

BDOS		equ	00005h
SMALL		equ	4000		; size of A, B and C
BIG		equ	8000		; size of the block asked for later

system		macro	func
		ld	c,func
		call	BDOS
		endm

		cseg

main:		call	dos2check
		jp	c,main.nodos2
		call	heapinit
		jp	c,main.nomap

		fpalloc	fpa,SMALL	; A
		jp	c,main.oom
		fpalloc	fpb,SMALL	; B
		jp	c,main.oom
		fpalloc	fpc,SMALL	; C
		jp	c,main.oom

		ld	hl,fpa		; print A and B
		ld	de,out_a
		call	putfp
		ld	hl,fpb
		ld	de,out_b
		call	putfp
		call	p2restore
		ld	de,rep1
		system	_STROUT

		fpfree	fpa		; free A, then B
		fpfree	fpb

		fpalloc	fpd,BIG		; ask for a block twice the size
		jp	c,main.oom

		ld	hl,fpd
		ld	de,out_d
		call	putfp
		call	p2restore
		ld	de,rep2
		system	_STROUT

		ld	hl,fpb		; does the new block start where B did?
		ld	de,fpd
		ld	b,4
main.cmp:	ld	a,(de)
		cp	(hl)
		jr	nz,main.differ
		inc	hl
		inc	de
		djnz	main.cmp
		ld	de,msg_same
		jr	main.verdict
main.differ:	ld	de,msg_diff
main.verdict:	push	de		; p2restore modifies DE, so the message
		call	p2restore	;   address has to be saved across it
		pop	de
		system	_STROUT

		fpfree	fpc		; tidy up
		fpfree	fpd
		call	p2restore
		system	_TERM0

main.oom:	ld	de,msg_oom
		jr	main.abort
main.nodos2:	ld	de,msg_dos1
		jr	main.abort
main.nomap:	ld	de,msg_nomap
main.abort:	push	de		; p2restore modifies DE, so the message
		call	p2restore	;   address has to be saved across it
		pop	de
		system	_STROUT
		system	_TERM0

; ----------------------------------------------------------------------
; putfp - write a far pointer into a 12-character field as
;         "SSS NNN XXXX": slot and segment in decimal, offset in hex.
;
; In:		HL -> the far pointer
;		DE -> the output field
; Modifies:	AF, BC, DE, HL, IX
; ----------------------------------------------------------------------

putfp:		ld	(fp_p),hl
		ld	(out_p),de

		ld	a,(hl)		; the slot byte
		ld	hl,(out_p)
		ld	e," "
		call	bin2dec8	; HL ends just past the three digits
		ld	(hl)," "
		inc	hl
		ld	(out_p),hl

		ld	hl,(fp_p)	; the segment byte
		inc	hl
		ld	a,(hl)
		ld	hl,(out_p)
		ld	e," "
		call	bin2dec8
		ld	(hl)," "
		inc	hl
		ex	de,hl		; DE -> where the offset goes

		ld	hl,(fp_p)	; the offset word
		inc	hl
		inc	hl
		ld	a,(hl)
		inc	hl
		ld	h,(hl)
		ld	l,a		; HL = offset
		call	bin2hex16
		ret

		dseg

fpa:		defs	4		; far pointer: block A
fpb:		defs	4		; far pointer: block B
fpc:		defs	4		; far pointer: block C
fpd:		defs	4		; far pointer: the 8000-byte block
fp_p:		defs	2		; putfp: the far pointer it was given
out_p:		defs	2		; putfp: where it is writing

rep1:		defb	"Three 4000-byte blocks.  slot seg  offset",13,10
		defb	"  A: "
out_a:		defs	12
		defb	13,10
		defb	"  B: "
out_b:		defs	12
		defb	13,10
		defb	"Freeing A, then B, then asking for 8000 bytes.",13,10,"$"

rep2:		defb	"  new block: "
out_d:		defs	12
		defb	13,10,"$"

msg_same:	defb	"It starts exactly where B did: the two merged.",13,10,"$"
msg_diff:	defb	"It is somewhere else: no merge happened.",13,10,"$"
msg_oom:	defb	"Out of mapper memory.",13,10,"$"
msg_dos1:	defb	"This program needs MSX-DOS2.",13,10,"$"
msg_nomap:	defb	"No memory mapper found.",13,10,"$"

		end

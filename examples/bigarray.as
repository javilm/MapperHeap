; bigarray.as - MapperHeap example 4: data larger than one block.
;
; A block never spans two segments, so 16372 bytes is the largest one
; MapperHeap will give you. Anything bigger has to be split up by the program.
; This example builds a 64 KB byte array out of eight 8 KB blocks and provides
; one routine, "at", that turns an array index into an address you can use.
;
; The array is filled with a pattern, then read back and checked.
;
;       array index (0-65535)
;         |
;         +-- bits 15-13 --> which block   (index / 8192)
;         +-- bits 12-0  --> which byte    (index mod 8192)
;
; A note on speed: this program calls "at" once per byte, so it does 131072
; far-pointer calculations and takes several seconds. It is written that way
; because random access is what the example is about. A program that walks the
; array in order would deref once per block and then use plain Z80 addressing
; inside it, which is what the fill loop of a real program would do.
;
; Shows:  splitting data across blocks, index-to-far-pointer arithmetic,
;         deref used heavily (the window cache is what makes this bearable).
; Build:  see make.bat

		.z80

		include	dos2func.inc
		include	alloc.inc
		include	farptr.inc

		external dos2check	; in dos2chec.as
		external bin2dec16	; in bin2str.as

BDOS		equ	00005h
NBLK		equ	8		; number of blocks
BLKSZ		equ	8192		; payload bytes in each one

system		macro	func
		ld	c,func
		call	BDOS
		endm

		cseg

main:		call	dos2check
		jp	c,main.nodos2
		call	heapinit
		jp	c,main.nomap

; --- allocate the eight blocks -----------------------------------------

		ld	b,NBLK
		ld	hl,fptab
main.aloop:	push	bc
		push	hl
		ld	bc,BLKSZ
		call	halloc		; HL already points at the table entry
		jp	c,main.oom
		pop	hl
		ld	de,4
		add	hl,de		; -> next table entry
		pop	bc
		djnz	main.aloop

		call	p2restore
		ld	de,msg_alloc
		system	_STROUT

; --- fill the array ----------------------------------------------------

		ld	hl,0		; index
main.floop:	push	hl
		call	at		; HL -> that byte, in page 2
		ex	de,hl		; DE -> the byte
		pop	hl
		push	hl
		call	value		; A = the value for this index
		ld	(de),a
		pop	hl
		inc	hl
		ld	a,h		; stop when the index wraps to 0,
		or	l		;   i.e. after all 65536 of them
		jr	nz,main.floop

		call	p2restore
		ld	de,msg_fill
		system	_STROUT

; --- read it back and check --------------------------------------------

		ld	hl,0
		ld	(bad),hl	; no mismatches yet
		ld	hl,0		; and back to index 0
main.cloop:	push	hl
		call	at		; HL -> that byte, in page 2
		ld	a,(hl)
		ld	(got),a
		pop	hl
		push	hl
		call	value		; A = what it should be
		ld	b,a
		ld	a,(got)
		cp	b
		jr	z,main.cnext
		ld	hl,(bad)	; count the mismatches
		inc	hl
		ld	(bad),hl
main.cnext:	pop	hl
		inc	hl
		ld	a,h
		or	l
		jr	nz,main.cloop

		ld	hl,(bad)
		ld	ix,num_bad
		ld	e," "
		call	bin2dec16
		call	p2restore
		ld	de,rep
		system	_STROUT

; --- free the blocks ---------------------------------------------------

		ld	b,NBLK
		ld	hl,fptab
main.zloop:	push	bc
		push	hl
		call	hfree
		pop	hl
		ld	de,4
		add	hl,de
		pop	bc
		djnz	main.zloop

		call	p2restore
		ld	de,msg_freed
		system	_STROUT
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
; at - make array index HL addressable.
;
; In:		HL = array index, 0-65535
; Out:		HL = the address of that byte, in page 2
; Modifies:	AF, BC, DE, HL
;
; The far pointer of the block is copied into atfp, the index's offset within
; the block is added to the block's own offset field, and the result is
; handed to deref.
; ----------------------------------------------------------------------

at:		ld	a,h		; which block? index / 8192, which is
		and	0e0h		;   the top three bits of H
		rlca
		rlca
		rlca			; A = 0-7
		add	a,a
		add	a,a		; A = block * 4 = table offset
		ld	e,a
		ld	d,0
		push	hl
		ld	hl,fptab
		add	hl,de
		ld	de,atfp
		ld	bc,4
		ldir			; atfp = that block's far pointer
		pop	hl

		ld	a,h		; which byte? index mod 8192, which is
		and	01fh		;   H with the top three bits cleared
		ld	h,a
		ld	de,(atfp+2)	; add it to the block's own offset
		add	hl,de
		ld	(atfp+2),hl

		derefp	atfp		; HL -> the byte
		ret

; ----------------------------------------------------------------------
; value - the value the array should hold at index HL.
;
; In:		HL = array index
; Out:		A  = (index AND 255) XOR (index / 8192)
; Modifies:	AF, BC
; ----------------------------------------------------------------------

value:		ld	a,h
		and	0e0h
		rlca
		rlca
		rlca			; A = block number, 0-7
		ld	b,a
		ld	a,l		; low byte of the index
		xor	b
		ret

		dseg

fptab:		defs	NBLK*4		; one far pointer per block
atfp:		defs	4		; far pointer built by "at"
bad:		defs	2		; mismatches found
got:		defs	1		; byte read back

msg_alloc:	defb	"Allocated 8 blocks of 8 KB (64 KB).",13,10,"$"
msg_fill:	defb	"Filled. Checking...",13,10,"$"
rep:		defb	"Mismatches: "
num_bad:	defs	5
		defb	13,10,"$"
msg_freed:	defb	"Blocks freed.",13,10,"$"
msg_oom:	defb	"Out of mapper memory.",13,10,"$"
msg_dos1:	defb	"This program needs MSX-DOS2.",13,10,"$"
msg_nomap:	defb	"No memory mapper found.",13,10,"$"

		end

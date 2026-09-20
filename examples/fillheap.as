; fillheap.as - MapperHeap example 2: fill the heap, then empty it again.
;
; Allocates 2K blocks one after another until halloc reports that there is no
; mapper memory left, reports how many blocks that was and how much memory
; they came to, then frees every one of them. The hblocks counter is printed
; before and after the freeing, so it can be seen returning to zero.
;
; Shows:  halloc's out-of-memory return, keeping a table of far pointers,
;         hfree, and reading hblocks.
; Build:  see make.bat

		.z80

		include	dos2func.inc
		include	alloc.inc
		include	farptr.inc

		external dos2check	; in dos2chec.as
		external bin2dec16	; in bin2str.as

BDOS		equ	00005h
MAXBLK		equ	4096		; entries in the far-pointer table
BLKSZ		equ	2048		; payload bytes per block (2 KB)

system		macro	func
		ld	c,func
		call	BDOS
		endm

		cseg

main:		call	dos2check
		jp	c,main.nodos2
		call	heapinit
		jp	c,main.nomap

		ld	hl,0
		ld	(count),hl

; --- allocate until the heap or the table runs out --------------------

main.alloc:	ld	hl,(count)	; is the table full?
		ld	de,MAXBLK
		or	a
		sbc	hl,de
		jr	nc,main.full

		ld	hl,(count)	; entry address = fptab + count*4
		add	hl,hl
		add	hl,hl
		ld	de,fptab
		add	hl,de		; HL -> fptab[count]
		ld	bc,BLKSZ
		call	halloc
		jr	c,main.done	; CY = out of mapper memory

		ld	hl,(count)
		inc	hl
		ld	(count),hl
		jr	main.alloc

main.full:	ld	a,1		; stopped for lack of table, not memory
		ld	(tabfull),a

; --- report what we got ------------------------------------------------

main.done:	ld	hl,(count)	; number of blocks
		ld	ix,num_blk
		ld	e," "
		call	bin2dec16

		ld	hl,(count)	; KB = count * 2, since BLKSZ is 2 KB
		add	hl,hl
		ld	ix,num_kb
		ld	e," "
		call	bin2dec16

		ld	hl,(hblocks)	; what the library says is allocated
		ld	ix,num_out
		ld	e," "
		call	bin2dec16

		call	p2restore	; page 2 back before printing
		ld	de,rep1
		system	_STROUT

		ld	a,(tabfull)
		or	a
		jr	z,main.free
		ld	de,msg_full
		system	_STROUT

; --- free every block --------------------------------------------------

main.free:	ld	hl,0
		ld	(idx),hl
main.floop:	ld	hl,(idx)
		ld	de,(count)
		or	a
		sbc	hl,de
		jr	nc,main.fdone	; idx >= count -> all freed

		ld	hl,(idx)	; entry address = fptab + idx*4
		add	hl,hl
		add	hl,hl
		ld	de,fptab
		add	hl,de
		call	hfree		; HL -> the far pointer halloc wrote

		ld	hl,(idx)
		inc	hl
		ld	(idx),hl
		jr	main.floop

main.fdone:	ld	hl,(hblocks)	; should be back to zero
		ld	ix,num_end
		ld	e," "
		call	bin2dec16

		call	p2restore
		ld	de,rep2
		system	_STROUT
		system	_TERM0

main.nodos2:	ld	de,msg_dos1
		jr	main.abort
main.nomap:	ld	de,msg_nomap
main.abort:	push	de		; p2restore modifies DE, so the message
		call	p2restore	;   address has to be saved across it
		pop	de
		system	_STROUT
		system	_TERM0

		dseg

count:		defs	2		; blocks allocated
idx:		defs	2		; index while freeing
tabfull:	defb	0		; 1 = stopped because the table filled

rep1:		defb	"Allocated "
num_blk:	defs	5
		defb	" blocks of 2 KB ("
num_kb:		defs	5
		defb	" KB).",13,10
		defb	"hblocks now reads "
num_out:	defs	5
		defb	".",13,10,"$"

rep2:		defb	"All freed. hblocks now reads "
num_end:	defs	5
		defb	".",13,10,"$"

msg_full:	defb	"(Stopped because the table filled, not the heap.)",13,10,"$"
msg_dos1:	defb	"This program needs MSX-DOS2.",13,10,"$"
msg_nomap:	defb	"No memory mapper found.",13,10,"$"

fptab:		defs	MAXBLK*4	; one far pointer per block

		end

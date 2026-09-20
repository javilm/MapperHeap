; strlist.as - MapperHeap example 3: a linked list that lives in mapper RAM.
;
; Reads lines typed at the keyboard until an empty line is entered. Each line
; goes into its own block of mapper RAM, and the blocks are chained into a
; list by far pointers stored inside the blocks themselves. The list is then
; walked and printed back, and finally freed.
;
; This is the example to read if you want to see how a data structure made of
; far pointers is built and walked. Three things in it are the point:
;
;   1. The link fields live INSIDE the blocks, in mapper RAM. The only far
;      pointers in ordinary RAM are "head", "tail" and the scratch ones.
;   2. Nothing read out of a block is used after the window may have moved.
;      The text of a line is copied into linebuf, in ordinary RAM, BEFORE
;      p2restore is called and the line is printed.
;   3. When freeing the list, the next link is copied out of a node BEFORE
;      that node is freed. After hfree the block's contents are gone.
;
; Node layout, inside one heap block:
;
;       +0  next (4 bytes: a far pointer, offset FFFFh = end of list)
;       +4  length of the text (1 byte)
;       +5  the text itself (length bytes)
;
; Build:  see make.bat

		.z80

		include	dos2func.inc
		include	alloc.inc
		include	farptr.inc

		external dos2check	; in dos2chec.as

BDOS		equ	00005h
MAXLINE		equ	60		; longest line accepted
NODENEXT	equ	0		; node: the next far pointer
NODELEN		equ	4		; node: the length byte
NODETEXT	equ	5		; node: the first text byte

system		macro	func
		ld	c,func
		call	BDOS
		endm

		cseg

main:		call	dos2check
		jp	c,main.nodos2
		call	heapinit
		jp	c,main.nomap

		ld	hl,NULLOFF	; the list starts empty
		ld	(head+2),hl	; only the offset field marks null

		call	p2restore
		ld	de,msg_intro
		system	_STROUT

; --- read lines until an empty one -------------------------------------

main.read:	call	p2restore	; a BDOS call is coming
		ld	de,msg_prompt
		system	_STROUT
		ld	de,inbuf
		system	_BUFIN		; inbuf+1 = count, inbuf+2.. = text
		ld	de,crlf
		system	_STROUT		; _BUFIN leaves the cursor on the line

		ld	a,(inbuf+1)	; how many characters were typed?
		or	a
		jp	z,main.show	; none -> stop reading (jp: out of jr range)

		ld	l,a		; block size = NODETEXT + length
		ld	h,0
		ld	de,NODETEXT
		add	hl,de
		ld	b,h
		ld	c,l
		ld	hl,newfp
		call	halloc
		jp	c,main.oom

; --- fill the new node in -----------------------------------------------

		derefp	newfp		; HL -> the node, in page 2
		push	hl		; keep the node's address
		inc	hl
		inc	hl		; -> next.offset
		ld	(hl),0ffh
		inc	hl
		ld	(hl),0ffh	; next = null: this is the last node
		pop	hl
		ld	de,NODELEN
		add	hl,de		; -> the length byte
		ld	a,(inbuf+1)
		ld	(hl),a
		inc	hl		; -> the text
		ex	de,hl		; DE -> the text, in page 2
		ld	hl,inbuf+2	; the typed line, in ordinary RAM
		ld	c,a
		ld	b,0
		ldir			; copy it into the block

; --- link the node on at the end of the list ---------------------------

		fpnull	head		; is the list still empty?
		jr	nz,main.append
		fpcopy	head,newfp	; yes: this node is the head
		jr	main.settail

main.append:	derefp	tail		; no: write our far pointer into the old
					;   last node's next field
		ex	de,hl		; DE -> tail node's next field
		ld	hl,newfp
		ld	bc,4
		ldir

main.settail:	fpcopy	tail,newfp	; either way, we are the last node now
		jp	main.read

; --- walk the list and print it ----------------------------------------

main.show:	call	p2restore
		ld	de,msg_list
		system	_STROUT

		fpcopy	cur,head
main.sloop:	fpnull	cur
		jp	z,main.free	; end of the list

		derefp	cur		; HL -> this node
		fpsave	nextfp		; nextfp = node.next; HL advances to
					;   the length byte
		ld	a,(hl)
		ld	(linelen),a
		inc	hl		; -> the text
		ld	c,a
		ld	b,0
		ld	de,linebuf
		ldir			; copy it OUT of the window first

		ld	hl,linebuf	; terminate it for _STROUT
		ld	a,(linelen)
		ld	e,a
		ld	d,0
		add	hl,de
		ld	(hl),"$"

		call	p2restore	; only now is a BDOS call safe
		ld	de,msg_bullet
		system	_STROUT
		ld	de,linebuf
		system	_STROUT
		ld	de,crlf
		system	_STROUT

		fpcopy	cur,nextfp	; on to the next node
		jp	main.sloop

; --- free the list -----------------------------------------------------

main.free:	fpcopy	cur,head
main.floop:	fpnull	cur
		jr	z,main.fdone

		derefp	cur		; HL -> the node
		fpsave	nextfp		; save the link BEFORE freeing it:
					;   after hfree the block is gone
		fpfree	cur
		fpcopy	cur,nextfp
		jp	main.floop

main.fdone:	call	p2restore
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

		dseg

head:		defs	4		; far pointer: first node
tail:		defs	4		; far pointer: last node
cur:		defs	4		; far pointer: node being visited
newfp:		defs	4		; far pointer: node just allocated
nextfp:		defs	4		; far pointer: link copied out of a node

linelen:	defs	1		; length of the line being printed
linebuf:	defs	MAXLINE+2	; the text, copied out of mapper RAM

inbuf:		defb	MAXLINE		; _BUFIN: maximum characters to accept
		defs	1		; _BUFIN: characters actually entered
		defs	MAXLINE+1	; _BUFIN: the text

crlf:		defb	13,10,"$"
msg_intro:	defb	"Type lines. An empty line ends the list.",13,10,"$"
msg_prompt:	defb	"> $"
msg_list:	defb	13,10,"The list, in order:",13,10,"$"
msg_bullet:	defb	"  - $"
msg_freed:	defb	"List freed.",13,10,"$"
msg_oom:	defb	"Out of mapper memory.",13,10,"$"
msg_dos1:	defb	"This program needs MSX-DOS2.",13,10,"$"
msg_nomap:	defb	"No memory mapper found.",13,10,"$"

		end

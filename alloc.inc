; alloc.inc - external declarations for the mapper heap library (alloc.as).
;
; Include this from any module that uses the library:
;
;	include	alloc.inc
;
; and link the library after your program:  ld myprog=myprog,alloc

	external	heapinit	; init mapper access + empty heap
					;   out: CY set = no mapper support
	external	halloc		; allocate a block
					;   in:  BC = payload bytes (1-16372)
					;        HL -> 4-byte result buffer
					;   out: CY set = out of memory
	external	hfree		; free a block
					;   in:  HL -> far pointer from halloc
	external	deref		; make a far pointer addressable
					;   in:  HL -> 4-byte far pointer
					;   out: HL = address in page 2
	external	p2restore	; hand page 2 back to MSX-DOS
					;   call before EVERY BDOS call and
					;   before terminating!
	external	maptot		; total mapper RAM
					;   out: HL = number of 16K segments
	external	hblocks		; A WORD, not a routine: blocks handed
					;   out by halloc and not yet given back
					;   to hfree. The library never reads it;
					;   compare it across two runs that
					;   should be equivalent to find a leak

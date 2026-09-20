; heaptst2.as - heap free/reuse stress test.
;
;   Phase A: pseudo-random 1/2/4/8/12 KB blocks until >= 8 MB is allocated.
;            Every block's far pointer is recorded in fartab.
;   Phase B: free every 4th recorded block (25% of them).
;   Phase C: allocate blocks of random size 128..2047 bytes until >= 8 MB
;            more has been allocated - these land in the freed holes first,
;            then force the heap to grow further.
;
;   Log line: "o x-y ssss-eeee zzz nnnnnb"
;     o = operation: A = allocated, F = freed
;     x-y = slot-subslot, ssss-eeee = payload range, zzz = segment,
;     nnnnn = payload size in BYTES (not KB - phase C blocks are small)

        .z80
        include dos2func.inc

        include alloc.inc       ; the mapper heap library
        include farptr.inc      ; far-pointer macros + NULLOFF

        external dos2check
        external bin2dec8
        external bin2dec16
        external bin2hex16

BDOS     equ 00005h
OVERHEAD equ 4
TARGETKB equ 8192              ; phase A: stop once >= 8 MB allocated
TARGET2U equ 32768             ; phase C: stop once >= 32768 x 256 bytes = 8 MB
PRNGSEED equ 07eh              ; fixed seed -> identical run every time
MAXTAB   equ 2048              ; capacity of the far-pointer table
                               ; (8 MB / ~6.4 KB average block ~ 1300 blocks;
                               ; 2048 leaves margin for an unlucky size mix)

system  macro func
        ld   c,func
        call BDOS
        endm

        cseg

main:
        call dos2check
        jp   c,main.nodos2
        call heapinit           ; mapper access + empty heap in one call
        jp   c,main.nomap

        ld   a,PRNGSEED         ; init PRNG + counters
        ld   (prngst),a
        ld   hl,0
        ld   (totkb),hl
        ld   (nblk),hl
        ld   (fidx),hl
        ld   (units),hl

; ---------------- Phase A: allocate ~8MB of 1/2/4/8/12 KB blocks ----------
pha.loop:
        call prng               ; pick a size: index = 3 random bits
        and  7
        ld   l,a
        ld   h,0
        ld   de,kbtab
        add  hl,de
        ld   a,(hl)             ; A = block size in KB
        ld   (curkb),a

        ld   h,a                ; payload = KB*1024 - OVERHEAD
        ld   l,0                ; HL = KB*256
        add  hl,hl              ; KB*512
        add  hl,hl              ; KB*1024
        dec  hl
        dec  hl
        dec  hl
        dec  hl                 ; - OVERHEAD
        ld   b,h
        ld   c,l                ; BC = payload bytes

        ld   hl,resfp           ; allocate; far pointer lands in resfp
        call halloc
        jp   c,main.oom

        ; record the far pointer in fartab (for phase B)
        ld   hl,(nblk)
        ld   de,MAXTAB
        or   a
        sbc  hl,de
        jr   nc,pha.norec       ; table full -> just don't record
        ld   hl,(nblk)          ; entry address = fartab + nblk*4
        add  hl,hl
        add  hl,hl
        ld   de,fartab
        add  hl,de
        ex   de,hl
        ld   hl,resfp
        ld   bc,4
        ldir                    ; fartab[nblk] = resfp
        ld   hl,(nblk)
        inc  hl
        ld   (nblk),hl
pha.norec:

        ld   a,"A"              ; log the allocation
        ld   (opchar),a
        call printblk

        ld   hl,(totkb)         ; total += KB
        ld   a,(curkb)
        ld   c,a
        ld   b,0
        add  hl,bc
        ld   (totkb),hl
        ld   de,TARGETKB
        or   a
        sbc  hl,de
        jp   c,pha.loop         ; below 8MB -> keep going

; ---------------- Phase B: free every 4th recorded block ------------------
phb.loop:
        ld   hl,(fidx)          ; done all recorded blocks?
        ld   de,(nblk)
        or   a
        sbc  hl,de
        jp   nc,phc.start       ; fidx >= nblk -> phase C

        ld   hl,(fidx)          ; entry address = fartab + fidx*4
        add  hl,hl
        add  hl,hl
        ld   de,fartab
        add  hl,de
        push hl                 ; keep the entry address for hfree

        ld   de,resfp           ; copy entry into resfp so printblk sees it
        ld   bc,4
        ldir
        ld   a,"F"              ; log it BEFORE freeing (header still valid)
        ld   (opchar),a
        call printblk

        pop  hl                 ; free it: HL -> the far pointer
        call hfree

        ld   hl,(fidx)          ; fidx += 4 (every 4th block = 25%)
        ld   de,4
        add  hl,de
        ld   (fidx),hl
        jp   phb.loop

; ---------------- Phase C: ~8MB of small blocks (128..2047 bytes) ---------
phc.start:
phc.loop:
        call prng               ; size = 11 random bits, clamped to >= 128
        and  7
        ld   h,a                ; H = high 3 bits (0..7)
        call prng
        ld   l,a                ; HL = 0..2047
        ld   a,h
        or   a
        jr   nz,phc.szok        ; >= 256 -> fine
        ld   a,l
        cp   128
        jr   nc,phc.szok        ; 128..255 -> fine
        add  a,128              ; < 128 -> push into 128..255
        ld   l,a
phc.szok:
        ld   (cursz),hl
        ld   b,h
        ld   c,l                ; BC = payload bytes

        ld   hl,resfp
        call halloc
        jp   c,main.oom

        ld   a,"A"              ; log the allocation
        ld   (opchar),a
        call printblk

        ld   hl,(cursz)         ; units += ceil(size/256)
        ld   de,255
        add  hl,de
        ld   l,h                ; HL >> 8 = (size+255)/256
        ld   h,0
        ld   de,(units)
        add  hl,de
        ld   (units),hl
        ld   de,TARGET2U
        or   a
        sbc  hl,de
        jp   c,phc.loop         ; below 8MB -> keep going

        call p2restore          ; page 2 back to DOS
        ld   de,msg_done
        system _STROUT
        system _TERM0

main.nodos2:
        ld   de,msg_nodos2
        jr   main.abort
main.nomap:
        ld   de,msg_nomap
        jr   main.abort
main.oom:
        call p2restore
        ld   de,msg_oom
        system _STROUT
        system _TERM0
main.abort:
        system _STROUT
        system _TERM0

; prng - 8-bit Galois LFSR (period 255). State in prngst; returns byte in A.
prng:
        ld   a,(prngst)
        srl  a
        jr   nc,prng.1
        xor  0b8h
prng.1:
        ld   (prngst),a
        ret

; printblk - log "o x-y ssss-eeee zzz nnnnnb" for the block in resfp.
;   opchar = the operation letter. Size is read from the block's header, so
;   the block must still be intact (log frees BEFORE calling hfree).
printblk:
        ld   a,(opchar)         ; operation letter
        ld   (lin_op),a

        ld   a,(resfp+0)        ; slot -> primary (bits 1-0)
        ld   b,a
        and  3
        add  a,"0"
        ld   (lin_pri),a
        ld   a,b               ; -> subslot (bits 3-2)
        rrca
        rrca
        and  3
        add  a,"0"
        ld   (lin_sub),a

        derefp resfp            ; map the block; HL -> payload start
        ld   (pstart),hl        ; save payload start
        dec  hl
        dec  hl                 ; HL -> header
        ld   e,(hl)
        inc  hl
        ld   d,(hl)             ; DE = size word
        res  7,d               ; clear the free bit
        ld   (psize),de         ; save whole-block size

        ld   hl,(pstart)        ; ssss = payload start (hex)
        ld   de,lin_s
        call bin2hex16
        ld   hl,(pstart)        ; eeee = last payload byte
        ld   de,(psize)
        add  hl,de
        ld   de,OVERHEAD+1
        or   a
        sbc  hl,de
        ld   de,lin_e
        call bin2hex16

        ld   a,(resfp+1)        ; segment, decimal, 3 columns
        ld   hl,lin_seg
        ld   e," "
        call bin2dec8

        ld   hl,(psize)         ; payload bytes = size - OVERHEAD
        ld   de,OVERHEAD
        or   a
        sbc  hl,de
        ld   ix,lin_sz          ; 5 decimal columns
        ld   e," "
        call bin2dec16

        call p2restore          ; page 2 back to DOS before printing
        ld   de,line
        system _STROUT
        ret

        dseg

prngst:  defs 1                 ; PRNG state
curkb:   defs 1                 ; phase A: current block size in KB
cursz:   defs 2                 ; phase C: current payload size in bytes
totkb:   defs 2                 ; phase A: running total, KB
units:   defs 2                 ; phase C: running total, 256-byte units
nblk:    defs 2                 ; number of far pointers recorded in fartab
fidx:    defs 2                 ; phase B: index of next block to free
opchar:  defs 1                 ; log letter: "A" or "F"
resfp:   defs 4                 ; far pointer for the current operation
pstart:  defs 2                 ; payload start address (page-2 window)
psize:   defs 2                 ; whole-block size in bytes

kbtab:   defb 1,2,4,8,12,4,8,12 ; phase A sizes (KB) indexed by prng & 7

fartab:  defs MAXTAB*4          ; recorded far pointers (phase A blocks)

; line buffer: "o x-y ssss-eeee zzz nnnnnb",CR,LF,"$"
line:
lin_op:  defs 1
         defb " "
lin_pri: defs 1
         defb "-"
lin_sub: defs 1
         defb " "
lin_s:   defs 4
         defb "-"
lin_e:   defs 4
         defb " "
lin_seg: defs 3
         defb " "
lin_sz:  defs 5
         defb "b",13,10,"$"

msg_done:   defb "Done: 8MB allocated, 25% freed, 8MB reallocated.",13,10,"$"
msg_nodos2: defb "ERROR: needs MSX-DOS2.",13,10,"$"
msg_nomap:  defb "ERROR: no memory mapper.",13,10,"$"
msg_oom:    defb "Out of mapper memory.",13,10,"$"

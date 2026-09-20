# Routine reference

Every public name in the library, one by one: what it does, what it takes,
what it gives back, and which registers it destroys. The library is
`alloc.as`; its declarations are in `alloc.inc`; the far-pointer macros are in
`farptr.inc`.

Read [../README.md](../README.md) first for the far-pointer layout and the
page-2 rule — this file assumes both.

## Index

| name | file | what it is |
|---|---|---|
| [`heapinit`](#heapinit--start-the-library) | `alloc.as` | routine — start the library |
| [`halloc`](#halloc--allocate-a-block) | `alloc.as` | routine — allocate a block |
| [`hfree`](#hfree--free-a-block) | `alloc.as` | routine — free a block |
| [`deref`](#deref--make-a-far-pointer-addressable) | `alloc.as` | routine — make a far pointer addressable |
| [`p2restore`](#p2restore--hand-page-2-back-to-msx-dos) | `alloc.as` | routine — hand page 2 back to MSX-DOS |
| [`maptot`](#maptot--total-mapper-ram) | `alloc.as` | routine — total mapper RAM |
| [`hblocks`](#hblocks--how-many-blocks-are-currently-allocated) | `alloc.as` | **a word in memory**, not a routine |
| [`NULLOFF`](#the-far-pointer-macros-farptrinc) | `farptr.inc` | equate — the offset value meaning "null" |
| [`fpcopy`, `fpsave`, `fpnull`, `derefp`](#the-far-pointer-macros-farptrinc) | `farptr.inc` | macros |
| [`dos2check`](#dos2check--is-this-msx-dos2) | `dos2chec.as` | routine — MSX-DOS2 detector |

The order in which they are normally called: `dos2check`, `heapinit`, then
any mix of `halloc`, `deref`, `hfree` and `p2restore`, with `p2restore` last
before the program ends.

---

## `heapinit` — start the library

Call once, before anything else in the library, and after you have confirmed
that this is MSX-DOS2. It finds MSX-DOS2's mapper support routines, takes note
of every mapper in the machine, records what MSX-DOS had in page 2 so that
`p2restore` can put it back, and starts with an empty heap.

No mapper memory is claimed until the first `halloc`, so calling `heapinit`
costs nothing in RAM.

| | |
|---|---|
| In | nothing |
| Out | CY set = no mapper support; CY clear = ready |
| Modifies | `AF BC DE HL`, and also `IX`, `IY` and the shadow registers |

The extended BIOS call that `heapinit` makes destroys `IX`, `IY` and the
shadow register set, which is why they are listed. If your program keeps
anything in the shadow set, save it around this call.

```
		call	heapinit
		jp	c,nomapper	; CY = this machine has no mapper
```

Calling `heapinit` a second time restarts the heap: it empties the free list
without returning the segments already claimed, which invalidates every far
pointer returned before the call. There is no reason to call it twice; it is
documented here because a retry loop could reach it unintentionally.

---

## `halloc` — allocate a block

Finds a free block big enough, splits it if the leftover is worth keeping, and
writes a far pointer to the block's usable bytes into a 4-byte buffer that you
supply. When nothing on the free list fits, it claims a fresh 16 KB segment
from MSX-DOS2 — the mapper that MSX-DOS2 calls the primary one first, then the
others automatically — and tries again.

| | |
|---|---|
| In | `BC` = payload size in bytes (1–16372)<br>`HL` = address of a 4-byte buffer for the result |
| Out | CY set = out of memory, buffer untouched<br>CY clear = buffer holds the block's far pointer |
| Modifies | `AF BC DE HL` |

```
		ld	bc,1000		; payload size in bytes
		ld	hl,myptr	; a "defs 4" somewhere in your data
		call	halloc
		jp	c,outofmem
```

Notes:

- **16372 bytes is the hard maximum.** A block lives inside one segment, and
  a segment has 16376 usable bytes after its two end markers, of which 4 go on
  the block's own bookkeeping. A larger request fails with carry set — it does
  not partially succeed.
- **A request under 8 bytes occupies 8.** A free block has to be able to hold
  two far-pointer links (4 bytes each) plus its two size words, which is 12
  bytes in total, so nothing smaller than that is ever created.
- **The buffer belongs to the caller.** The library writes 4 bytes there and
  never reads that buffer again. Copy the far pointer wherever you like.
- **CY set means out of memory for real**: every mapper in the machine was
  asked and none had a free segment.

---

## `hfree` — free a block

Returns a block to the heap. If the blocks physically next to it inside the
same segment are free, they are merged with it into one larger free block, so
that a long run of allocations and frees does not fragment the heap.

| | |
|---|---|
| In | `HL` = address of the block's far pointer, as `halloc` wrote it |
| Out | nothing (no error is possible) |
| Modifies | `AF BC DE HL` |

```
		ld	hl,myptr
		call	hfree
```

Rules, none of which the library checks:

- Free each block **at most once**. Freeing a block twice corrupts the heap.
- Free only far pointers that came from `halloc`, unmodified. In particular do
  not adjust the offset to point into the middle of a block and then free
  that.
- After the call the far pointer names memory the heap may hand to somebody
  else. Do not use it again.

---

## `deref` — make a far pointer addressable

Brings the far pointer's segment into the page-2 window and returns the live
16-bit address of the byte it names.

| | |
|---|---|
| In | `HL` = address of a 4-byte far pointer |
| Out | `HL` = 8000h + offset — the byte, mapped and ready to use |
| Modifies | `AF DE HL` |

```
		ld	hl,myptr
		call	deref
		ld	(hl),42		; write the block's first byte
```

or, when the far pointer is at a fixed label, the macro from `farptr.inc`:

```
		derefp	myptr
		ld	(hl),42
```

The library remembers which slot and segment the window is showing, so calling
`deref` repeatedly for the same segment costs a handful of compares; only a
change of segment costs a mapper write, and only a change of slot costs a slot
switch. Walking a chain of blocks in one segment is therefore cheap, and there
is no reason to hoard the returned address.

**The returned address is temporary.** It is valid only until the next
`deref`, `halloc`, `hfree`, `p2restore` or BDOS call, any of which may move
the window. Store far pointers, and call `deref` again when the block is
needed.

---

## `p2restore` — hand page 2 back to MSX-DOS

Puts back the slot and segment that MSX-DOS had in page 2 when `heapinit` ran,
and marks the library's record of the window as stale so that the next `deref`
maps afresh.

| | |
|---|---|
| In | nothing |
| Out | nothing |
| Modifies | `AF BC DE HL` |

**Call it before every BDOS call and before your program terminates.** See
[the one rule](../README.md#the-one-rule-you-must-not-break) in the README for
what goes wrong otherwise.

It is safe to call at any time and any number of times, including before
`heapinit` has run — in that case it does nothing at all, which makes it safe
in an error path that can be reached before the heap is up.

```
		call	p2restore	; page 2 back to DOS
		ld	de,message
		ld	c,_STROUT	; only now is a BDOS call safe
		call	BDOS
```

---

## `maptot` — total mapper RAM

Returns how many 16 KB segments of mapper RAM MSX-DOS2 is managing, added up
across every mapper in the machine. Multiply by 16 for kilobytes.

| | |
|---|---|
| In | nothing (`heapinit` must have run) |
| Out | `HL` = total number of 16 KB segments |
| Modifies | `AF BC DE HL IX` |

This is the machine's total as MSX-DOS2 reports it, which is not quite the
machine's total. MSX-DOS2 holds each mapper's segment count in a single byte,
so a 4 MB mapper is reported as 255 segments rather than 256, and `maptot` is
short by one segment for every 4 MB mapper in the machine.

It is also the total, not what is still free.

---

## `hblocks` — how many blocks are currently allocated

**A word in memory, not a routine.** `halloc` adds one to it every time it
succeeds, `hfree` subtracts one every time it is called, and `heapinit` sets
it to zero. So it holds the number of blocks the library has allocated and
not yet had returned to it.

| | |
|---|---|
| Read | at any time, with `ld hl,(hblocks)` |
| Write | never, from outside the library |

The library itself never reads it. It exists for one job: finding blocks your
program allocated and forgot to free (a *memory leak*).

The way to use it is a comparison, not a check against zero. Run your program
over two inputs that ought to leave it in the same state — the same operation
done ten times and a thousand times, say — and read `hblocks` at the same
point in both runs. The two numbers must be equal. They will usually not be
zero, because whatever your program is still legitimately holding at that
moment is counted too, and that is exactly why comparing two runs tells you
something that one run cannot.

```
		ld	hl,(hblocks)	; declared external in alloc.inc
```

---

## The far-pointer macros (`farptr.inc`)

`farptr.inc` defines the equate `NULLOFF` (0FFFFh, the offset value that means
"this far pointer does not point at anything") and six macros for the things
every program ends up doing with far pointers. They expand inline — treat them
as the two to four instructions they are, and mind what they destroy.

| macro | what it does | destroys |
|---|---|---|
| `fpcopy dst,src` | copy the far pointer at `src` to `dst` | `BC DE HL F` |
| `fpsave dst` | copy the far pointer at `(HL)` to `dst` | `BC DE HL F` |
| `fpnull fp` | test the far pointer at `fp`: Z set = null | `DE HL F` |
| `derefp fp` | `ld hl,fp` then `call deref` | `AF BC DE HL` |
| `fpalloc fp,size` | allocate `size` payload bytes, far pointer into `fp` | `AF BC DE HL` |
| `fpfree fp` | free the block whose far pointer is at `fp` | `AF BC DE HL` |

What each one expands to:

```
; File: farptr.inc (expansions, for reference)

fpcopy dst,src  ->  ld hl,src / ld de,dst / ld bc,4 / ldir
fpsave dst      ->  ld de,dst / ld bc,4 / ldir
fpnull fp       ->  ld hl,(fp+2) / ld de,NULLOFF / or a / sbc hl,de
derefp fp       ->  ld hl,fp / call deref
fpalloc fp,size ->  ld bc,size / ld hl,fp / call halloc
fpfree fp       ->  ld hl,fp / call hfree
```

Points to note:

- **`fpcopy` takes the destination first**, like `ld`. Reversing the two
  arguments is a common error.
- **`fpsave` is for pulling a far pointer out of the window.** After `deref`
  has left `HL` pointing at a link inside a mapped block, `fpsave` copies
  those 4 bytes into ordinary RAM, where they survive the next window change.
  This is the only safe way to follow a chain.
- **`fpnull` only sets flags.** Follow it with `jr z` or `jr nz`. It compares
  the offset field alone, which is why a null far pointer's slot and segment
  bytes are ignored and may hold anything.
- **`derefp`, `fpalloc` and `fpfree` need the library declared**, so include
  `alloc.inc` before using them. `alloc.as` itself uses only the other three,
  since it *is* `halloc` and `hfree`.
- **`fpalloc` still sets carry on failure.** It is `halloc` with its two
  argument registers loaded, nothing more, so follow it with `jr c` or `jp c`
  exactly as you would follow the call.
- **Both arguments must be fixed addresses** — a label or an expression built
  from labels. None of these macros can work through an address held in a
  variable, and `fpalloc`'s size must likewise be a constant or an expression,
  not a value already computed into `BC`. Where a program walks a table of far
  pointers, or works out a size at run time, it writes the `ld`/`call` pair out
  by hand; `alloc.as` does the same for the few copies that go through a
  variable.

---

## `dos2check` — is this MSX-DOS2?

In `dos2chec.as`, not part of the heap library, but the library needs MSX-DOS2
and this is the polite way to find out. It asks MSX-DOS for its version
number.

| | |
|---|---|
| In | nothing |
| Out | `A` = MSX-DOS major version (1 = MSX-DOS1, 2 or more = MSX-DOS2)<br>CY set = this is **not** MSX-DOS2 |
| Modifies | `AF BC DE HL` |

```
		call	dos2check
		jp	c,nodos2	; CY = MSX-DOS1, give up politely
```

`dos2chec.as` includes nothing and depends on nothing, so it can be linked
into any program on its own.

# The tests

The library is exercised by one stress program, `heaptst2.as`, in the `tests/`
directory. It does not check itself: it prints a line for every operation it
performs, and those lines are checked afterwards.

The separation is intentional. A test that decides for itself whether it
passed can only detect the errors its author anticipated. A log of every block
the heap allocated, checked afterwards against every other block, also
detects errors that were not anticipated, the most important of which is two
live blocks overlapping.

## What is in `tests/`

| file | what it is |
|---|---|
| `heaptst2.as` | the stress test program |
| `bin2str.as` | number-to-text routines the test uses to print its log |
| `make.bat` | assembles and links the test |
| `heaptst2.html` | An animated Javascript-based visualization of the `heaptst2.com` log. Helps visualize and understand how blocks are allocated inside the MSX memory. |

`bin2str.as` is a general-purpose module, not part of the test as such. It
exports `bin2hex4`, `bin2hex8`, `bin2hex16`, `bin2dec8` and `bin2dec16`, which
convert a value in a register into a fixed-width string in a buffer the caller
provides — right-justified, space-padded. The test uses three of them to build
its log lines. Nothing in the library itself needs this file.

The assembler is given plain file names, with no paths, so everything
`heaptst2.as` includes or links against has to be alongside `make.bat` before
building. Copy `alloc.as`, `dos2chec.as` and the three include files up from
the parent directory, or edit the paths:

```
copy ..\alloc.as
copy ..\alloc.inc
copy ..\farptr.inc
copy ..\dos2func.inc
copy ..\dos2chec.as
```

`heaptst2.as` includes `dos2func.inc` for the MSX-DOS function numbers,
`alloc.inc` for the library's declarations and `farptr.inc` for the
far-pointer macros; `alloc.as` includes `farptr.inc` as well.

```
; File: tests/make.bat

as heaptst2.as
as alloc.as
as dos2chec.as
as bin2str.as
ld heaptst2=heaptst2,alloc,dos2chec,bin2str
del *.rel
del *.sym
```

## What `heaptst2.as` does

Three phases, run back to back.

**Phase A: fill.** Allocate blocks of 1, 2, 4, 8 or 12 KB, the size picked
at random, until about 8 MB has been allocated. Every far pointer is recorded
in a table in the program's own memory (`fartab`, 2048 entries, more than the
run needs.

**Phase B: free a quarter of them.** Walk that table and free **every
fourth** block, so a quarter of what phase A allocated goes back to the heap.
The freed blocks are scattered through every segment the heap has claimed, and
they are of mixed sizes, so what is left is a heap with free gaps throughout
it rather than a heap with one large free area at the end.

**Phase C: refill with small blocks.** Allocate blocks of a pseudo-random
size between 128 and 2047 bytes until another 8 MB has been allocated. These
are much smaller than the gaps phase B left, so most of them have to be taken
from those gaps rather than from fresh segments. This is the part that exercises
splitting, and it is the part that would expose a split that writes the wrong
size into a size word.

The random sizes come from an 8-bit shift-register generator with a fixed
starting value (`PRNGSEED`, 7Eh), so every run produces exactly the same
sequence of sizes and therefore exactly the same log. A failure can be
reproduced.

The program needs a machine with a lot of mapper RAM: around 12-13 MB. In a real
MSX this means either using several 4 MB memory mapper cartridges in a slot expander,
or at least one 16 MB [Memory Samurai](https://legacy.lavandeira.net/2016/07/multi-review-msx-memory-mapper-mega-mapper-and-memory-samurai-part-2-of-2/) cartridge. In an emulator such as [openMSX](https://openmsx.org/) just add several 4 MB extensions.

If it runs out of memory it stops cleanly and prints `Out of mapper memory.` rather than misbehaving.

## The log

One line per operation, allocation and free alike:

```
o x-y ssss-eeee zzz nnnnnb

o     = A for allocated, F for freed
x-y   = slot-subslot the block's segment lives in
ssss  = address of the first payload byte, in the page-2 window, hex
eeee  = address of the last payload byte, hex
zzz   = segment number, decimal
nnnnn = payload size in bytes, decimal
```

For example:

```
A 3-0 BC12-BFF9 017  1000b
F 3-0 BC12-BFF9 017  1000b
```

Two details of how the line is produced matter:

- **The size is read back out of the block's own header**, not taken from the
  variable the program asked for. So the line records what the library
  actually built, not what the test intended. A size word written wrongly
  shows up in the log.
- **A free is logged before `hfree` is called**, while the block's header is
  still intact and can be read.

The log is captured by redirecting the program's output to a file under
MSX-DOS2.

Open the file [heaptst2.html](../tests/heaptst2.html) in your web browser for a visualization
of the test program log. You'll be able to see 8 MBs worth of blocks being allocated in phase A, then some
of these blocks being freed (phase B), and 8 MBs worth of small blocks being allocated in the freed gaps.

## How the log is checked

The log is replayed off-line, one line at a time, against a list of the blocks
believed to be live. At each step:

- an **A** line must not overlap any live block. The comparison uses the whole
  block, size words included, not just the payload. An off-by-two in a header
  would otherwise slip through. Overlap is only meaningful within one segment
  in one slot, so the slot and segment fields are part of the comparison.
- an **F** line must match a live block exactly: same slot, same segment, same
  start, same size. A free of something never allocated, or of a block with
  the wrong size attached, fails here.
- sizes must be exact, not merely plausible.

## What the runs showed

A run of these three phases at a smaller scale (673 operations across three
mappers, an internal 512 KB one and external 1 MB and 4 MB ones in expanded
slots) replayed with **zero violations**: no allocation ever overlapped a
live block, and every free matched.

A second result follows from the same run. In phase C, the 466 small blocks
consumed **no new segments**. They fitted entirely into the gaps left by
phase B and into the space remaining inside segments already claimed. This is
positive evidence that three mechanisms work as intended: the gaps could be
found, so the free list was correct after all those frees; they could be
divided, so splitting produced usable remainders; and adjacent freed blocks
had been joined, since otherwise the gaps would have been too small to hold a
2 KB block.

An overlap check alone would not establish this. A heap that never reuses
freed space would also pass an overlap check.

## Checking your own program for blocks never given back

Separately from this test, the library exports `hblocks`: a word in memory
holding how many blocks it has allocated and not yet had returned to it. It is
the tool for finding blocks your own program allocated and forgot to free (a
*memory leak*). How to use it is in
[api.md](api.md#hblocks--how-many-blocks-are-currently-allocated): read it at
the same point in two runs that should leave the program in the same state, and
the two numbers must match.

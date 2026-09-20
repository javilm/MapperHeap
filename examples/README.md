# Examples

Five short programs, each demonstrating a different part of MapperHeap. They
are meant to be read in the order below: each one assumes what the previous
one showed.

| program | what it demonstrates |
|---|---|
| [`meminfo.as`](meminfo.as) | the smallest possible program: start the library, ask how much mapper RAM the machine has |
| [`fillheap.as`](fillheap.as) | allocate until the heap is exhausted, then free everything and watch `hblocks` return to zero |
| [`strlist.as`](strlist.as) | a linked list whose links live inside the blocks, in mapper RAM |
| [`bigarray.as`](bigarray.as) | data larger than one block: a 64 KB array spread over eight 8 KB blocks |
| [`coalesce.as`](coalesce.as) | freeing two blocks that touch, and seeing them merge |

## Building

`make.bat` builds all five. The assembler is given plain file names, with no
paths, so everything the examples include or link against has to be copied
into this directory first: `alloc.as`, `dos2chec.as` and the three include
files from the parent directory, and `bin2str.as` from `tests/`.

```
copy ..\alloc.as
copy ..\alloc.inc
copy ..\farptr.inc
copy ..\dos2func.inc
copy ..\dos2chec.as
copy ..\tests\bin2str.as
make
```

Every example includes `dos2func.inc` for the MSX-DOS function numbers,
`alloc.inc` for the library's declarations and `farptr.inc` for the
far-pointer macros; `alloc.as` includes `farptr.inc` as well.

All five need MSX-DOS2 and a memory mapper, and each one says so and exits if
either is missing.

## What each program does

### `meminfo.as`

Calls `heapinit` (in `alloc.as`) and then `maptot` (in `alloc.as`), and prints
the result in 16 KB segments and in kilobytes. It allocates nothing, which
makes it the shortest complete program that uses the library, and a quick way
to confirm that the library comes up at all on a given machine or emulator
configuration.

### `fillheap.as`

Allocates 2 KB blocks in a loop until `halloc` (in `alloc.as`) returns with
carry set, keeping every far pointer in a table. It then reports how many
blocks it got, how much memory that is, and what `hblocks` (in `alloc.as`)
reads. It frees all of them and prints `hblocks` again, which should be zero.

This is the program to run when you want to know how much of a machine's
mapper RAM is actually available to a program after MSX-DOS2 has taken its
share.

### `strlist.as`

Reads lines from the keyboard until an empty line is entered, storing each one
in its own block, and chains the blocks into a list using far pointers stored
inside the blocks themselves. It then walks the list, prints it, and frees it.

Three things in this program are the reason it is here:

- The links live **inside** the blocks. The only far pointers in ordinary RAM
  are `head`, `tail` and a couple of scratch ones.
- The text of a line is copied out of the block into `linebuf`, in ordinary
  RAM, **before** `p2restore` is called and the line is printed. Nothing read
  through the page-2 window is used after the window may have moved.
- When the list is freed, the next link is copied out of a node **before** the
  node is freed. After `hfree` (in `alloc.as`) the block's contents are no
  longer valid to read.

The third of those is the mistake that is easiest to make and hardest to find,
because freeing a node and then following its link usually appears to work
until something else is allocated.

### `bigarray.as`

A block never spans two segments, so no single block can be larger than 16372
bytes. This program builds a 64 KB array out of eight 8 KB blocks and provides
one routine, `at`, that converts an array index into an address in page 2:
the top three bits of the index select the block, the remaining thirteen give
the offset within it. The array is filled with a pattern, read back, and
checked.

It calls `at` once per byte, so it performs 131072 far-pointer calculations
and takes several seconds. That is deliberate — random access is what the
example is about — but a program that walks such an array in order would call
`deref` (in `alloc.as`) once per block and use ordinary Z80 addressing inside
it.

### `coalesce.as`

Allocates three 4000-byte blocks, frees two of them that happen to touch, and
then asks for 8000 bytes. Because the two freed blocks merged into one free
block of 8008 bytes, and because 8008 minus the 8004 needed leaves less than
the 12-byte minimum, the whole merged block is taken — so the new block starts
at exactly the address the second of the two freed blocks started at. The
program prints all three far pointers and says whether they match.

The exact numbers depend on the heap being empty when the program starts,
which is why the three allocations are the first thing it does.

## A note on these listings

None of these five programs has been assembled or run. They are written
against the documented interface in [../doc/api.md](../doc/api.md), and the
patterns in them are taken from `tests/heaptst2.as`, which has been run. Treat
them as drafts until they have been through the assembler at least once.

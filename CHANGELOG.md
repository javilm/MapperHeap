# Changelog

## v1.0.1 — 2026-09-23

- `deref` (in `alloc.as`) now preserves `BC`, as its documented register list
  has always said it does. The full-remap path calls the BIOS routine
  `ENASLT`, which destroys every register, so a caller holding a value in `BC`
  across a call to `deref` lost it. This only happened when the far pointer's
  segment was in a different slot from the one already in page 2, which is why
  it went unnoticed: the cache-hit and segment-only paths were unaffected.

## v1.0.0 — 2026-09-18

First public release.

- The heap over MSX-DOS2 memory-mapper RAM, in `alloc.as`: `heapinit`,
  `halloc`, `hfree`, `deref`, `p2restore`, `maptot`, and the `hblocks`
  counter.
- The far-pointer equate `NULLOFF` and the macros `fpcopy`, `fpsave`,
  `fpnull`, `derefp`, `fpalloc` and `fpfree`, in `farptr.inc`.
- The MSX-DOS2 detector `dos2check`, in `dos2chec.as`.
- MSX-DOS function number equates, in `dos2func.inc`.
- Documentation: `README.md`, `doc/api.md`, `doc/internals.md` and
  `doc/tests.md`.
- Five example programs in `examples/`, and the free/reuse stress test in
  `tests/`.

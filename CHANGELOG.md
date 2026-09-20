# Changelog

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

rem Copy alloc.as and dos2chec.as from the parent directory, and bin2str.as
rem from tests\, into this directory before running this.

as meminfo.as
as fillheap.as
as strlist.as
as bigarray.as
as coalesce.as

as alloc.as
as dos2chec.as
as bin2str.as

ld meminfo=meminfo,alloc,dos2chec,bin2str
ld fillheap=fillheap,alloc,dos2chec,bin2str
ld strlist=strlist,alloc,dos2chec
ld bigarray=bigarray,alloc,dos2chec,bin2str
ld coalesce=coalesce,alloc,dos2chec,bin2str

del *.rel
del *.sym

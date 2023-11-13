Motivation
==========

Virtual machine or ISO disc images or other "file systems within a file" or
sometimes object / database files can have intentionally large holes / sparsity.
Corrupted torrent downloads may, meanwhile, have very large holes by accident.

While these files can be easily identified with `ls -ls` or `stat` comparing the
allocated blocks and seek-addressable file size, I could find no standard Unix
command-line tool to count/list holes.  (A quick web search will show numerous C
programming examples to use the Unix API to list holes, though.)  So here is
(probably another) one.

Usage
=====

```
  holes [optional-params] [files: string...]

Show hole & data segments for files

  -f=, --format= string "" emit format interpolating:
                             $count : number of data|hole segments
                             $path  : path name of REGULAR FILE from $*
                             $map   : map of all data&hole segments
                             $nul   : a NUL byte
                           "" => "$count\t$path\n$holes\n"
```

Example
=======

```sh
truncate -s 5000 x; printf hi >>x; holes x
```

prints on a file system with 4096-byte blocks:

```
2 x
	hole	4096
	data	906
```

Related
=======

`filefrag` is a similar but distinct utility which uses a less portable Linux
FIEMAP `ioctl`.  Distinctness-wise, for example, I get "4 extents" from a
`filefrag foo.xfs`, while `holes` reports 42814 hole|data segments[^1].

[^1]: This is admittedly after running `xfs_fsr`.

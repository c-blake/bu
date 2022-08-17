import tables, algorithm, posix, cligen/[dents, osUt, posixUt, statx]
type IdKind = enum user, group, both
type Order  = enum id, count

proc print*[Id](hdr: string, ids: Table[Id, int], nm: Table[Id, string],
                order=id) =
  var pairs, sorted: seq[tuple[id: Id, count: int]]
  for id, cnt in ids: pairs.add (id, cnt)
  case order
  of id   : sorted = pairs.sortedByIt( it[0])
  of count: sorted = pairs.sortedByIt(-it[1])
  echo hdr, "\tNentry\tName"
  for tup in sorted:
    echo tup[0], "\t", tup[1], "\t", nm.getOrDefault(tup[0], "MISSING")

proc fsids*(roots: seq[string], kind=both, order=id,
            recurse=0, follow=false, xdev=false, eof0=false) =
  ## Print a histogram of uids and/or gids used by a file tree
  var uids: Table[Uid, int]
  var gids: Table[Gid, int]
  let doU = kind in { user , both }
  let doG = kind in { group, both }
  for root in (if roots.len > 0: roots else: @[ "." ]):
    forPath(root, recurse, true, follow, xdev, eof0, stderr,
            depth, path, nmAt, ino, dt, lst, dfd, dst, did):
      if doU: uids.mgetOrPut(lst.st_uid, 0).inc
      if doG: gids.mgetOrPut(lst.st_gid, 0).inc
    do: discard                         # No pre-recurse
    do: discard                         # No post-recurse
    do: recFailDefault("fsids", path)   # cannot recurse
  if doU: print "#Uid", uids, users() , order
  if doG: print "#Gid", gids, groups(), order

when isMainModule: import cligen; dispatch fsids, help = {
  "kind"   : "kind of ids to report user, group, both",
  "order"  : "sort order: up by id or down by count",
  "recurse": "recursion limit for dirs in `roots`; 0=unbounded",
  "follow" : "follow symbolic links to dirs in recursion",
  "xdev"   : "block recursion from crossing devices" }

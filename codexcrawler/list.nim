import std/os
import pkg/chronos
import pkg/chronicles
import pkg/datastore
import pkg/datastore/typedds
import pkg/stew/byteutils
import pkg/stew/endians2
import pkg/questionable
import pkg/questionable/results
import pkg/stint

import std/sets
import std/sequtils
import std/os

import ./types
import ./utils/datastoreutils

logScope:
  topics = "list"

type
  List* = ref object of RootObj
    name: string
    store: TypedDatastore
    items: HashSet[Nid]
    emptySignal: ?Future[void]

proc encode(s: Nid): seq[byte] =
  s.toBytes()

proc decode(T: type Nid, bytes: seq[byte]): ?!T =
  if bytes.len < 1:
    return success(Nid.fromStr("0"))
  return Nid.fromBytes(bytes)

proc saveItem(this: List, item: Nid): Future[?!void] {.async.} =
  without itemKey =? Key.init(this.name / $item), err:
    return failure(err)
  ?await this.store.put(itemKey, item)
  return success()

method load*(this: List): Future[?!void] {.async, base.} =
  without queryKey =? Key.init(this.name), err:
    return failure(err)
  without iter =? (await query[Nid](this.store, Query.init(queryKey))), err:
    return failure(err)

  while not iter.finished:
    without item =? (await iter.next()), err:
      return failure(err)
    without value =? item.value, err:
      return failure(err)
    if value > 0:
      this.items.incl(value)

  info "Loaded list", name = this.name, items = this.items.len
  return success()

proc contains*(this: List, nid: Nid): bool =
  this.items.anyIt(it == nid)

method add*(this: List, nid: Nid): Future[?!void] {.async, base.} =
  if this.contains(nid):
    return success()

  this.items.incl(nid)

  if err =? (await this.saveItem(nid)).errorOption:
    return failure(err)

  if s =? this.emptySignal:
    trace "List no longer empty.", name = this.name
    s.complete()
    this.emptySignal = Future[void].none

  return success()

method remove*(this: List, nid: Nid): Future[?!void] {.async, base.} =
  if this.items.len < 1:
    return failure(this.name & "List is empty.")

  this.items.excl(nid)
  without itemKey =? Key.init(this.name / $nid), err:
    return failure(err)
  ?await this.store.delete(itemKey)
  return success()

proc len*(this: List): int =
  this.items.len

proc new*(
    _: type List, name: string, store: TypedDatastore
): List =
  List(name: name, store: store)

proc createList*(dataDir: string, name: string): ?!List =
  without store =? createTypedDatastore(dataDir / name), err:
    return failure(err)
  success(List.new(name, store))

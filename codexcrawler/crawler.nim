import pkg/chronicles
import pkg/chronos
import pkg/questionable
import pkg/questionable/results

import ./dht
import ./list
import ./nodeentry

logScope:
  topics = "crawler"

type Crawler* = ref object
  dht: Dht
  todoNodes: List
  okNodes: List
  nokNodes: List

proc handleNodeNotOk(c: Crawler, target: NodeEntry) {.async.} =
  if err =? (await c.nokNodes.add(target)).errorOption:
    error "Failed to add not-OK-node to list", err = err.msg

proc handleNodeOk(c: Crawler, target: NodeEntry) {.async.} =
  if err =? (await c.okNodes.add(target)).errorOption:
    error "Failed to add OK-node to list", err = err.msg

proc addNewTodoNode(c: Crawler, nodeId: NodeId): Future[?!void] {.async.} =
  let entry = NodeEntry(id: nodeId, value: "todo")
  return await c.todoNodes.add(entry)

proc addNewTodoNodes(c: Crawler, newNodes: seq[Node]) {.async.} =
  for node in newNodes:
    if err =? (await c.addNewTodoNode(node.id)).errorOption:
      error "Failed to add todo-node to list", err = err.msg

proc step(c: Crawler) {.async.} =
  without target =? (await c.todoNodes.pop()), err:
    error "Failed to get todo node", err = err.msg

  # todo: update target timestamp

  without newNodes =? (await c.dht.getNeighbors(target.id)), err:
    trace "getNeighbors call failed", node = $target.id, err = err.msg
    await c.handleNodeNotOk(target)
    return

  await c.handleNodeOk(target)
  await c.addNewTodoNodes(newNodes)

proc worker(c: Crawler) {.async.} =
  try:
    while true:
      await c.step()
      await sleepAsync(3.secs)
  except Exception as exc:
    error "Exception in crawler worker", msg = exc.msg
    quit QuitFailure

proc start*(c: Crawler): Future[?!void] {.async.} =
  if c.todoNodes.len < 1:
    let nodeIds = c.dht.getRoutingTableNodeIds()
    info "Loading routing-table nodes to todo-list...", nodes = nodeIds.len
    for id in nodeIds:
      if err =? (await c.addNewTodoNode(id)).errorOption:
        error "Failed to add routing-table node to todo-list", err = err.msg
        return failure(err)

  info "Starting crawler..."
  asyncSpawn c.worker()
  return success()

proc new*(
    T: type Crawler, dht: Dht, todoNodes: List, okNodes: List, nokNodes: List
): Crawler =
  Crawler(dht: dht, todoNodes: todoNodes, okNodes: okNodes, nokNodes: nokNodes)

import pkg/chronos
import pkg/questionable/results
import pkg/asynctest/chronos/unittest

import ../../../codexcrawler/components/todolist
import ../../../codexcrawler/utils/asyncdataevent
import ../../../codexcrawler/types
import ../../../codexcrawler/state
import ../mocks/mockstate
import ../mocks/mockmetrics
import ../helpers

suite "TodoList":
  var
    nid: Nid
    state: MockState
    metrics: MockMetrics
    todo: TodoList

  setup:
    nid = genNid()
    state = createMockState()
    metrics = createMockMetrics()

    todo = TodoList.new(state, metrics)

    (await todo.start()).tryGet()

  teardown:
    (await todo.stop()).tryGet()
    state.checkAllUnsubscribed()

  proc fireNewNodesDiscoveredEvent(nids: seq[Nid]) {.async.} =
    (await state.events.newNodesDiscovered.fire(nids)).tryGet()

  proc fireNodesExpiredEvent(nids: seq[Nid]) {.async.} =
    (await state.events.nodesExpired.fire(nids)).tryGet()

  test "discovered nodes are added to todo list":
    await fireNewNodesDiscoveredEvent(@[nid])
    let item = (await todo.pop).tryGet()

    check:
      item == nid

  test "expired nodes are added to todo list":
    await fireNodesExpiredEvent(@[nid])
    let item = (await todo.pop).tryGet()

    check:
      item == nid

  test "newNodesDiscovered event updates todo metric":
    await fireNewNodesDiscoveredEvent(@[nid])

    check:
      metrics.todo == 1

  test "nodesExpired event updates todo metric":
    await fireNodesExpiredEvent(@[nid])

    check:
      metrics.todo == 1

  test "does not store duplicates":
    await fireNewNodesDiscoveredEvent(@[nid])
    await fireNodesExpiredEvent(@[nid])

    check:
      metrics.todo == 1

  test "pop on empty todo list waits until item is added":
    let popFuture = todo.pop()
    check:
      not popFuture.finished

    await fireNewNodesDiscoveredEvent(@[nid])

    check:
      popFuture.finished
      popFuture.value.tryGet() == nid

  test "pop updates todo metric":
    await fireNewNodesDiscoveredEvent(@[nid])

    discard (await todo.pop()).tryGet()

    check:
      metrics.todo == 0

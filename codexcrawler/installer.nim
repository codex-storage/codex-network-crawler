import pkg/chronos
import pkg/questionable/results

import ./state
import ./metrics
import ./component
import ./components/dht
import ./components/crawler
import ./components/timetracker
import ./components/nodestore
import ./components/dhtmetrics

proc createComponents*(state: State): Future[?!seq[Component]] {.async.} =
  var components: seq[Component] = newSeq[Component]()

  without dht =? (await createDht(state)), err:
    return failure(err)

  without nodeStore =? createNodeStore(state), err:
    return failure(err)

  let metrics = createMetrics(state.config.metricsAddress, state.config.metricsPort)

  without dhtMetrics =? createDhtMetrics(state, metrics), err:
    return failure(err)

  components.add(nodeStore)
  components.add(dht)
  components.add(Crawler.new(dht, state.config))
  components.add(TimeTracker.new(state, nodeStore))
  components.add(dhtMetrics)
  return success(components)

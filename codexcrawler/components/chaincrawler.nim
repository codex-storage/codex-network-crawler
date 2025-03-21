import pkg/chronicles
import pkg/chronos
import pkg/questionable/results

import ../state
import ../components/requeststore
import ../services/marketplace
import ../component
import ../types

logScope:
  topics = "chaincrawler"

type ChainCrawler* = ref object of Component
  state: State
  store: RequestStore
  marketplace: MarketplaceService

proc onNewRequest(c: ChainCrawler, rid: Rid): Future[?!void] {.async: (raises: []).} =
  return await c.store.update(rid)

method start*(c: ChainCrawler): Future[?!void] {.async.} =
  info "starting..."

  proc onRequest(rid: Rid): Future[?!void] {.async: (raises: []).} =
    return await c.onNewRequest(rid)

  ?await c.marketplace.subscribeToNewRequests(onRequest)
  ?await c.marketplace.iteratePastNewRequestEvents(onRequest)
  return success()

method stop*(c: ChainCrawler): Future[?!void] {.async.} =
  return success()

proc new*(
    T: type ChainCrawler,
    state: State,
    store: RequestStore,
    marketplace: MarketplaceService,
): ChainCrawler =
  ChainCrawler(state: state, store: store, marketplace: marketplace)

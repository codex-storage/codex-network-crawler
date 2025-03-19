import pkg/chronicles
import pkg/chronos
import pkg/questionable
import pkg/questionable/results

import ../state
import ../services/metrics
import ../services/marketplace
import ../component

logScope:
  topics = "chainmetrics"

type ChainMetrics* = ref object of Component
  state: State
  metrics: Metrics
  marketplace: MarketplaceService

proc step(c: ChainMetrics): Future[?!void] {.async: (raises: []).} =
  # replace slotFills entirely:
  # iterate all requests in requestStore:
    # get state of request on chain
    # if failed/canceled/error:
      # if last-seen is old (1month?3months?)
        # delete entry
    # else (request is running):
      # count:
        # total running
        # total num slots
        # total size of request
  # iter finished: update metrics!


  without slotFills =? (await c.marketplace.getRecentSlotFillEvents()), err:
    trace "Unable to get recent slotFill events from chain", err = err.msg
    return success() # We don't propagate this error.
    # The call is allowed to fail and the app should continue as normal.

  c.metrics.setSlotFill(slotFills.len)
  return success()

method start*(c: ChainMetrics): Future[?!void] {.async.} =
  info "starting..."

  proc onStep(): Future[?!void] {.async: (raises: []), gcsafe.} =
    return await c.step()

  if c.state.config.marketplaceEnable:
    await c.state.whileRunning(onStep, 10.minutes)

  return success()

method stop*(c: ChainMetrics): Future[?!void] {.async.} =
  return success()

proc new*(
    T: type ChainMetrics,
    state: State,
    metrics: Metrics,
    marketplace: MarketplaceService,
): ChainMetrics =
  ChainMetrics(state: state, metrics: metrics, marketplace: marketplace)

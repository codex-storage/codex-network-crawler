import std/net
import std/sequtils
import pkg/chronicles
import pkg/libp2p
import pkg/codexdht
import ./utils/version

let doc =
  """
Codex Network Crawler. Generates network metrics.

Usage:
  codexcrawler [--logLevel=<l>] [--publicIp=<a>] [--metricsAddress=<ip>] [--metricsPort=<p>] [--dataDir=<dir>] [--discoveryPort=<p>] [--bootNodes=<n>] [--stepDelay=<ms>] [--revisitDelay=<m>]

Options:
  --logLevel=<l>          Sets log level [default: INFO]
  --publicIp=<a>          Public IP address where this instance is reachable.
  --metricsAddress=<ip>   Listen address of the metrics server [default: 0.0.0.0]
  --metricsPort=<p>       Listen HTTP port of the metrics server [default: 8008]
  --dataDir=<dir>         Directory for storing data [default: crawler_data]
  --discoveryPort=<p>     Port used for DHT [default: 8090]
  --bootNodes=<n>         Semi-colon-separated list of Codex bootstrap SPRs [default: testnet_sprs]
  --stepDelay=<ms>        Delay in milliseconds per crawl step [default: 1000]
  --revisitDelay=<m>      Delay in minutes after which a node can be revisited [default: 10] (24h)
"""

import strutils
import docopt

type Config* = ref object
  logLevel*: string
  publicIp*: string
  metricsAddress*: IpAddress
  metricsPort*: Port
  dataDir*: string
  discPort*: Port
  bootNodes*: seq[SignedPeerRecord]
  stepDelayMs*: int
  revisitDelayMins*: int

proc `$`*(config: Config): string =
  "Crawler:" & " logLevel=" & config.logLevel & " publicIp=" & config.publicIp &
    " metricsAddress=" & $config.metricsAddress & " metricsPort=" & $config.metricsPort &
    " dataDir=" & config.dataDir & " discPort=" & $config.discPort & " bootNodes=" &
    config.bootNodes.mapIt($it).join(";") & " stepDelay=" & $config.stepDelayMs &
    " revisitDelay=" & $config.revisitDelayMins

proc getDefaultTestnetBootNodes(): seq[string] =
  @[
    "spr:CiUIAhIhAiJvIcA_ZwPZ9ugVKDbmqwhJZaig5zKyLiuaicRcCGqLEgIDARo8CicAJQgCEiECIm8hwD9nA9n26BUoNuarCEllqKDnMrIuK5qJxFwIaosQ3d6esAYaCwoJBJ_f8zKRAnU6KkYwRAIgM0MvWNJL296kJ9gWvfatfmVvT-A7O2s8Mxp8l9c8EW0CIC-h-H-jBVSgFjg3Eny2u33qF7BDnWFzo7fGfZ7_qc9P",
    "spr:CiUIAhIhAyUvcPkKoGE7-gh84RmKIPHJPdsX5Ugm_IHVJgF-Mmu_EgIDARo8CicAJQgCEiEDJS9w-QqgYTv6CHzhGYog8ck92xflSCb8gdUmAX4ya78QoemesAYaCwoJBES39Q2RAnVOKkYwRAIgLi3rouyaZFS_Uilx8k99ySdQCP1tsmLR21tDb9p8LcgCIG30o5YnEooQ1n6tgm9fCT7s53k6XlxyeSkD_uIO9mb3",
    "spr:CiUIAhIhA6_j28xa--PvvOUxH10wKEm9feXEKJIK3Z9JQ5xXgSD9EgIDARo8CicAJQgCEiEDr-PbzFr74--85TEfXTAoSb195cQokgrdn0lDnFeBIP0QzOGesAYaCwoJBK6Kf1-RAnVEKkcwRQIhAPUH5nQrqG4OW86JQWphdSdnPA98ErQ0hL9OZH9a4e5kAiBBZmUl9KnhSOiDgU3_hvjXrXZXoMxhGuZ92_rk30sNDA",
    "spr:CiUIAhIhA7E4DEMer8nUOIUSaNPA4z6x0n9Xaknd28Cfw9S2-cCeEgIDARo8CicAJQgCEiEDsTgMQx6vydQ4hRJo08DjPrHSf1dqSd3bwJ_D1Lb5wJ4Qt_CesAYaCwoJBEDhWZORAnVYKkYwRAIgFNzhnftocLlVHJl1onuhbSUM7MysXPV6dawHAA0DZNsCIDRVu9gnPTH5UkcRXLtt7MLHCo4-DL-RCMyTcMxYBXL0",
    "spr:CiUIAhIhAzZn3JmJab46BNjadVnLNQKbhnN3eYxwqpteKYY32SbOEgIDARo8CicAJQgCEiEDNmfcmYlpvjoE2Np1Wcs1ApuGc3d5jHCqm14phjfZJs4QrvWesAYaCwoJBKpA-TaRAnViKkcwRQIhANuMmZDD2c25xzTbKSirEpkZYoxbq-FU_lpI0K0e4mIVAiBfQX4yR47h1LCnHznXgDs6xx5DLO5q3lUcicqUeaqGeg",
    "spr:CiUIAhIhAgybmRwboqDdUJjeZrzh43sn5mp8jt6ENIb08tLn4x01EgIDARo8CicAJQgCEiECDJuZHBuioN1QmN5mvOHjeyfmanyO3oQ0hvTy0ufjHTUQh4ifsAYaCwoJBI_0zSiRAnVsKkcwRQIhAJCb_z0E3RsnQrEePdJzMSQrmn_ooHv6mbw1DOh5IbVNAiBbBJrWR8eBV6ftzMd6ofa5khNA2h88OBhMqHCIzSjCeA",
    "spr:CiUIAhIhAntGLadpfuBCD9XXfiN_43-V3L5VWgFCXxg4a8uhDdnYEgIDARo8CicAJQgCEiECe0Ytp2l-4EIP1dd-I3_jf5XcvlVaAUJfGDhry6EN2dgQsIufsAYaCwoJBNEmoCiRAnV2KkYwRAIgXO3bzd5VF8jLZG8r7dcLJ_FnQBYp1BcxrOvovEa40acCIDhQ14eJRoPwJ6GKgqOkXdaFAsoszl-HIRzYcXKeb7D9",
    "spr:CiUIAhIhA2AEPzVj1Z_pshWAwvTp0xvRZTigIkYphXGZdiYGmYRwEgIDARo8CicAJQgCEiEDYAQ_NWPVn-myFYDC9OnTG9FlOKAiRimFcZl2JgaZhHAQvKCXugYaCwoJBES3CuORAnd-KkYwRAIgNwrc7n8A107pYUoWfJxL8X0f-flfUKeA6bFrjVKzEo0CID_0q-KO5ZAGf65VsK-d9rV3S0PbFg7Hj3Cv4aVX2Lnn",
    "spr:CiUIAhIhAuhggJhkjeRoR7MHjZ_L_naZKnjF541X0GXTI7LEwXi_EgIDARo8CicAJQgCEiEC6GCAmGSN5GhHsweNn8v-dpkqeMXnjVfQZdMjssTBeL8Qop2quwYaCwoJBJK-4V-RAncuKkYwRAIgaXWoxvKkzrjUZ5K_ayQHKNlYhUEzBXhGviujxfJiGXkCICbsYFivi6Ny1FT6tbofVBRj7lnaR3K9_3j5pUT4862k",
    "spr:CiUIAhIhA-pnA5sLGDVbqEXsRxDUjQEpiSAximHNbyqr2DwLmTq8EgIDARo8CicAJQgCEiED6mcDmwsYNVuoRexHENSNASmJIDGKYc1vKqvYPAuZOrwQyrekvAYaCwoJBIDHOw-RAnc4KkcwRQIhAJtKNeTykcE5bkKwe-vhSmqyBwc2AnexqFX1tAQGLQJ4AiBJOPseqvI3PyEM8l3hY3zvelZU9lT03O7MA_8cUfF4Uw",
  ]

proc getBootNodeStrings(input: string): seq[string] =
  if input == "testnet_sprs":
    return getDefaultTestnetBootNodes()
  return input.split(";")

proc stringToSpr(uri: string): SignedPeerRecord =
  var res: SignedPeerRecord
  try:
    if not res.fromURI(uri):
      warn "Invalid SignedPeerRecord uri", uri = uri
      quit QuitFailure
  except LPError as exc:
    warn "Invalid SignedPeerRecord uri", uri = uri, error = exc.msg
    quit QuitFailure
  except CatchableError as exc:
    warn "Invalid SignedPeerRecord uri", uri = uri, error = exc.msg
    quit QuitFailure
  res

proc getBootNodes(input: string): seq[SignedPeerRecord] =
  getBootNodeStrings(input).mapIt(stringToSpr(it))

proc parseConfig*(): Config =
  let args = docopt(doc, version = crawlerFullVersion)

  proc get(name: string): string =
    $args[name]

  return Config(
    logLevel: get("--logLevel"),
    publicIp: get("--publicIp"),
    metricsAddress: parseIpAddress(get("--metricsAddress")),
    metricsPort: Port(parseInt(get("--metricsPort"))),
    dataDir: get("--dataDir"),
    discPort: Port(parseInt(get("--discoveryPort"))),
    bootNodes: getBootNodes(get("--bootNodes")),
    stepDelayMs: parseInt(get("--stepDelay")),
    revisitDelayMins: parseInt(get("--revisitDelay")),
  )

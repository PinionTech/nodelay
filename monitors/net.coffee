util = require 'util'
fs   = require 'fs'
proc = require 'procfs'
Node  = require '../lib/node'

CHECK_INTERVAL = 5000

node = Node('net monitor').connect 'localhost', process.argv[2]

res = node.resources

oldTicks = {}

olds = {}
diff = (k, v) ->
  ret = 0
  if olds[k]
    ret = (v - olds[k]) / (CHECK_INTERVAL/1000)
  olds[k] = v
  ret

setInterval ->
  updata = {}
  proc.netdev (err, devices) ->
    for name, dev of devices
      continue if name is 'lo'
      updata[name] = receive: {}, transmit: {}
      updata[name].receive[k] = diff [name,'recv',k].join('.'), v for k, v of dev.receive
      updata[name].transmit[k] = diff [name,'send',k].join('.'), v for k, v of dev.transmit

    res.update updata

, CHECK_INTERVAL



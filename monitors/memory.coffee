util = require 'util'
fs   = require 'fs'
proc = require 'procfs'
Node  = require '../lib/node'

CHECK_INTERVAL = 5000

node = Node('memory monitor').connect 'localhost', process.argv[2]

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
  proc.meminfo (err, data) ->
    updata =
      memory:
        total: data.MemTotal
        free: data.MemFree + data.Buffers + data.Cached
        used: data.MemTotal - (data.MemFree + data.Buffers + data.Cached)
        pressure:
          active: diff 'active', data.Active
          inactive: diff 'inactive', data.Inactive
        commit:
          limit: data.CommitLimit
          total: data.Committed_AS
      swap:
        total: data.SwapTotal
        free: data.SwapFree
        used: data.SwapTotal - data.SwapFree

    res.update updata unless err

  proc.vmstat (err, data) ->
    updata =
      memory:
        pagefaults:
          minor: diff 'minor', data.pgfault
          major: diff 'major', data.pgmajfault

    res.update updata unless err

, CHECK_INTERVAL



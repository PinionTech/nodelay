util = require 'util'
fs   = require 'fs'
proc = require 'procfs'
Node  = require '../lib/node'

CHECK_INTERVAL = 5000

node = Node('disk monitor').connect 'localhost', process.argv[2]

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
  proc.partitions (err, partitions) ->
    return if err
    proc.diskstats (err, diskstats) ->
      return if err
      for name, pdata of partitions
        continue if pdata.major is 8 and pdata.minor % 16 isnt 0 #Skip non-disk partition entries
        ddata = diskstats[name]
        updata[name] =
          name: pdata.name
          size: pdata.blocks
          ios_in_progress: ddata.ios_in_progress
        for k, v of ddata when k not in ['ios_in_progress', 'dev_major', 'dev_minor', 'name']
          updata[name][k] = diff name+'.'+k, v

      res.update disk: updata

, CHECK_INTERVAL



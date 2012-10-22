util = require 'util'
fs   = require 'fs'
proc = require 'proc'
Node  = require '../lib/node'

CHECK_INTERVAL = 5000

node = Node('system monitor').connect 'localhost', process.argv[2]

res = node.resources

oldTicks = {}

setInterval ->
  proc.diskstats (err, data) ->
    res.update {disk: data} unless err
  proc.vmstat (err, data) ->
    res.update {vmstat: data} unless err
  proc.stat (err, data) ->
    res.update {stat: data} unless err

, CHECK_INTERVAL



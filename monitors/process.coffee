util = require 'util'
fs   = require 'fs'
proc = require 'proc'
Node  = require '../lib/node'

STATEMAP = {R:"running", S:"sleeping", D:"disk sleep", Z:"zombie", T:"stopped", W:"paging"}

CHECK_INTERVAL = 5000

node = Node('process monitor').connect 'localhost', process.argv[2]

node.on 'add resource', (msg) ->
  return unless typeof msg.resource is 'string'
  res = msg.data
  if res?.pidFile
    node.resource msg.resource, res 

node.on 'remove resource', (msg) ->
  return unless typeof msg.resource is 'string'
  node.unresource msg.resource


oldTicks = {}

procToMetrics = (p) ->
  m = {}

  m.running = true
  m.pid = p.pid
  m.stateCode = p.state
  m.state = STATEMAP[p.state]

  m.threads = p.num_threads

  m.memUsage = p.rss
  m.vmUsage = p.vsize

  ticks = parseInt(p.utime) + parseInt(p.stime)
  if oldTicks[p.pid]
    m.cpuUsage = (ticks - oldTicks[p.pid]) / (100 * (CHECK_INTERVAL / 1000))
  
  oldTicks[p.pid] = ticks

  
  m.children = (procToMetrics(child) for pid, child of p.children)

  m



setInterval ->
  proc (err, procs) ->
    #console.log "node.resources is", node.resources
    for name, res of node.resources
      pid = res.pidFile && fs.existsSync(res.pidFile) && parseInt fs.readFileSync res.pidFile, 'utf8'
      running = pid? && procs[pid]? 

      if running
        res.metric procToMetrics procs[pid]
      else
        res.metric {running}


, CHECK_INTERVAL



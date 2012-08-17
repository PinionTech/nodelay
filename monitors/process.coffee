util = require 'util'
fs   = require 'fs'
proc = require 'proc'
Node  = require '../lib/node'

STATEMAP = {R: "running", S:"sleeping", D:"disk sleep", Z:"zombie", T:"stopped", W:"paging"}

CHECK_INTERVAL = 5000

services = {}

node = Node('process monitor').connect 'localhost'

node.on 'add resource', ({data: service}) ->
  if service.pidFile
    services[service.name] = service 

node.on 'remove resource', ({data: service}) ->
  delete services[service.name]


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
    for name, service of services
      pid = service.pidFile && fs.existsSync(service.pidFile) && parseInt fs.readFileSync service.pidFile, 'utf8'
      running = pid? && procs[pid]? 

      if running
        node.send "metric", resource: name, metrics: procToMetrics procs[pid]
      else
        node.send "metric", resource: name, metrics: {running}


, CHECK_INTERVAL



util = require 'util'
fs   = require 'fs'
proc = require 'procfs'
Node  = require '../lib/node'

STATEMAP = {R:"running", S:"sleeping", D:"disk sleep", Z:"zombie", T:"stopped", W:"paging"}

CHECK_INTERVAL = 5000

node = Node('process monitor').connect 'localhost', process.argv[2]

selector = node.resource pidFile: '*'

oldTicks = {}

procToMetrics = (p) ->
  m = {}

  m.pid = p.pid
  m.stateCode = p.state
  m.state = STATEMAP[p.state]

  m.threads = p.num_threads

  m.memUsage = p.rss
  m.vmUsage = p.vsize

  ticks = parseInt(p.utime) + parseInt(p.stime)
  if oldTicks[p.pid]?
    m.cpuUsage = (ticks - oldTicks[p.pid]) / (100 * (CHECK_INTERVAL / 1000))
  
  oldTicks[p.pid] = ticks
  
  m.children = (procToMetrics(child) for pid, child of p.children)

  m


setInterval ->
  proc (err, procs) ->
    #console.log "node.resources is", node.resources
    selector.each (path, res) ->
      #console.log "res is", res
      data = res.data
      pid = data.pidFile && fs.existsSync(data.pidFile) && parseInt fs.readFileSync data.pidFile, 'utf8'
      running = pid? && procs[pid]?

      wasRunning = data.running
      res.update {running}

      if wasRunning?
        res.send 'up' if running and !wasRunning
        res.send 'down' if !running and wasRunning

      process = res.sub('process')
      if running
        process.update procToMetrics(procs[pid])#, 'clobber'



, CHECK_INTERVAL



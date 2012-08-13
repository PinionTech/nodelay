util = require 'util'
fs   = require 'fs'
proc = require 'proc'
Node  = require '../lib/node'

STATEMAP = {R: "running", S:"sleeping", D:"disk sleep", Z:"zombie", T:"stopped", W:"paging"}

CHECK_INTERVAL = 5000

services = {}

node = Node.connect 'localhost'

node.on 'add resource', ({data: service}) ->
  console.log "adding service", service 
  services[service.name] = service 

node.on 'remove resource', ({data: service}) ->
  delete services[service.name]

node.send 'monitor online'

setInterval ->
  proc (err, procs) ->
    for name, service of services
      #console.log "stuff", service.pidFile, fs.existsSync(service.pidFile), parseInt fs.readFileSync service.pidFile, 'utf8'
      pid = service.pidFile && fs.existsSync(service.pidFile) && parseInt fs.readFileSync service.pidFile, 'utf8'
      service.running = pid? && procs[pid]? 

      if service.running
        p = procs[pid]

        service.pid = pid        
        service.stateCode = p.state 
        service.state = STATEMAP[p.state]

        service.threads = p.num_threads
        service.childCount = p.children?.length or 0

        service.memUsage = p.rss
        service.vmUsage = p.vsize

        service.oldTicks = service.ticks
        service.ticks = parseInt(p.utime) + parseInt(p.stime)
        if service.oldTicks?
          service.cpuUsage = (service.ticks - service.oldTicks) / (100 * (CHECK_INTERVAL / 1000))

        metrics = {}
        metrics[k] = service[k] for k in "running pid stateCode state threads emUsage vmUsage cpuUsage".split(" ")
        metrics.children = service.childCount

        node.send "metric", resource: name, metrics: metrics
      else
        node.send "metric", resource: name, metrics: {running: service.running}


, CHECK_INTERVAL



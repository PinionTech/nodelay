util = require 'util'
path = require 'path'

{exec, spawn} = require 'child_process'
Node  = require '../lib/node'

node = Node('steam updates monitor').connect 'localhost'

watchers = {}

watch = (file, cb) ->
  child = spawn 'tail', ['-F', file]
  child.stdout.on 'data', (data) ->
    cb data.toString('utf8')
  child.on 'exit', ->
    setTimeout ->
      watch file, cb
    ,500
  child

node.on 'add resource', ({data: res}) ->
  if res.steamDir
    watchFile = path.join res.steamDir, "logs", "content_log.txt"

    watchers[res.name] ||= watch watchFile, (data) ->
      node.send "got data", data

node.on 'remove resource', ({data: res}) ->
  delete watchers[res]


# setInterval ->
#   proc (err, procs) ->
#     for name, service of services
#       pid = service.pidFile && fs.existsSync(service.pidFile) && parseInt fs.readFileSync service.pidFile, 'utf8'
#       running = pid? && procs[pid]? 

#       if running
#         node.send "metric", resource: name, metrics: procToMetrics procs[pid]
#       else
#         node.send "metric", resource: name, metrics: {running}


# , CHECK_INTERVAL



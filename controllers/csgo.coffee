Node = require '../lib/node'

node = Node.connect 'localhost'

#node.on '*', (msg) ->
#  console.log "got message", msg

node.on 'metric', ({data: {resource, metrics}}) ->
  console.log "got metrics for #{resource}", metrics
  
  if !metrics.running
    node.send 'start', resource


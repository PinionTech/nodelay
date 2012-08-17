Node = require '../lib/node'

node = Node('restarter').connect 'localhost'

node.on 'metric', ({data: {resource, metrics}}) ->
  if !metrics.running
    node.send 'start', resource


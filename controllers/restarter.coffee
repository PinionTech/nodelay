Node = require '../lib/node'

node = Node('restarter').connect 'localhost', process.argv[2]

node.on 'metric', ({resource, data: metrics}) ->
  if !metrics.running
    node.send 'start', resource


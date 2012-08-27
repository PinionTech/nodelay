Node = require '../lib/node'

node = Node('restarter').connect 'localhost', process.argv[2]

node.on 'metric', ({resource, data: metrics}) ->
  return unless typeof resource is 'string'
  if !metrics.running
    node.send resource:resource, type:'start'


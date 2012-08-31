Node = require '../lib/node'

node = Node('restarter').connect 'localhost', process.argv[2]

debounce = {}

node.on 'metric', ({resource, data: metrics}) ->
  return unless typeof resource is 'string'
  if !metrics.running and !debounce[resource]
    node.send resource:resource, type:'start'
    debounce[resource] = true
    setTimeout ->
      delete debounce[resource]
    , 30 * 1000


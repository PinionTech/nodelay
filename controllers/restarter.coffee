Node = require '../lib/node'

node = Node('restarter').connect 'localhost', process.argv[2]

debounce = {}

node.resource restart: true, (res) ->
  if !res.running and !debounce[resource]
    res.send 'start'
    debounce[resource] = true
    setTimeout ->
      delete debounce[resource]
    , 30 * 1000

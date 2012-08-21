Node = require '../lib/node'

node = Node('steam update restarter').connect 'localhost'

node.on 'steam update finished', ({data: {name, time}}) ->
  node.send 'restart', name


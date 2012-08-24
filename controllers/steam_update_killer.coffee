Node = require '../lib/node'

node = Node('steam update killer').connect 'localhost'

node.on 'steam update finished', ({data: {name, time}}) ->
  node.send 'stop', name


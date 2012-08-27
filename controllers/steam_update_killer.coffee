Node = require '../lib/node'

node = Node('steam update killer').connect 'localhost', process.argv[2]

node.on 'steam update finished', ({resource, data: {time}}) ->
  node.send 'stop', resource


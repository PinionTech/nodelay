Node = require '../lib/node'

node = Node('steam update killer').connect 'localhost', process.argv[2]

node.resource(steam: '*').on 'steam update finished', (res) -> res.send 'stop'
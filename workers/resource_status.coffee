util = require 'util'
Node = require '../lib/node'

node = Node('resource status').connect 'localhost', process.argv[2]

node.resource {}

setInterval ->
  console.log (new Date()).toISOString(), "resources", node.resources.data
,5000

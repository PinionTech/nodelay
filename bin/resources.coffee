util = require 'util'
Node = require '../lib/node'

node = Node('resources tool').connect 'localhost', process.argv[2]

updateTimer = null
node.resource {}, ->
  clearTimeout updateTimer
  updateTimer = setTimeout done, 500

done = ->
  console.log util.inspect node.resources.data, false, 9999, true
  process.exit()

setTimeout done, 5000

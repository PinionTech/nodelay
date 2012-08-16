util = require 'util'
Node = require '../lib/node'

RED   = '\u001b[31m'
BLUE  = '\u001b[34m'
RESET = '\u001b[0m'

node = Node.connect 'localhost'

node.on '*', (msg) ->
  header = "[#{msg.from} #{RED}#{msg.type}#{RESET}]"
  header += "\n" if typeof msg.data is 'object'
  console.log header, util.inspect msg.data, false, 2, true


util = require 'util'
Node = require '../../lib/node'

RED   = '\u001b[31m'
BLUE  = '\u001b[34m'
RESET = '\u001b[0m'

node = Node('logger').connect 'localhost', process.argv[2]

node.on '*', (msg) ->
  from = if typeof msg.from is 'object' then msg.from.join('>') else msg.from
  res = if typeof msg.resource is 'object' then msg.resource.join('>') else msg.resource
  header = "[#{from}: #{RED}#{msg.type} #{BLUE}#{res or ''}#{RESET}]"
  header += "\n" if typeof msg.data is 'object'
  console.log header, util.inspect msg.data, false, 1, true
  #console.log msg


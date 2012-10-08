util = require 'util'
Node = require '../lib/node'

RED   = '\u001b[31m'
BLUE  = '\u001b[34m'
RESET = '\u001b[0m'

node = Node('logger').connect 'localhost', process.argv[2]

node.on '*', (msg) ->
  return if msg.type is 'resource update'

  from = if typeof msg.from is 'object' then msg.from.join('>') else msg.from
  res = if typeof msg.resource is 'object' then msg.resource.join('>') else msg.resource
  header = "[#{from}: #{RED}#{msg.type} #{BLUE}#{res or ''}#{RESET}]"
  empty = false
  if typeof msg.data is 'object'
    empty = true
    for k of msg.data
      empty = false
      break
    header += "\n" unless empty

  if empty
    console.log (new Date()).toISOString(), header
  else
    console.log (new Date()).toISOString(), header, util.inspect msg.data, false, 1, true


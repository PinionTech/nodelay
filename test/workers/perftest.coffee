util = require 'util'
Node = require '../../lib/node'

RED   = '\u001b[31m'
BLUE  = '\u001b[34m'
RESET = '\u001b[0m'

node = Node('perftest').connect 'localhost', process.argv[2]

messages = 0
total = 0
INTERVAL = 5000

node.on '*', (msg) -> messages++; total++

setInterval ->
  console.log "#{messages*1000/INTERVAL} messages/second"
  console.log "#{total} total messages"
  messages = 0
, INTERVAL


Node = require './node'

node = Node.connect '127.0.0.1', process.argv[2]

setInterval ->
  console.log "sending metric"
  node.send type: "metric", data: [1,2,3]
, 1000

node.on 'hi', (msg) -> node.send msg

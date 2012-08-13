Node = require './node'

node = Node.listen()

node.on '*', (msg) ->
  console.log "got message", msg
  node.send {type: "hi", data: "I got a message"}

node.on 'metric', (msg) ->
  console.log "got metric", msg

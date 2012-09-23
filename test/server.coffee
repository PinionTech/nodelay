nodelay = require '../nodelay'

nodelay "server", ->
  @bind "0.0.0.0", 1234
  @pubkey "pubkey.pem" 

  @workers "logger"

  #@node.on "*", (msg) -> console.log msg

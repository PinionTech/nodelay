nodelay = require '../nodelay'

nodelay "server", ->
  @bind "0.0.0.0", 1234
  @pubkey "pubkey.pem"

  @workers "perftest"

  #@node.on "*", (msg) -> console.log msg

  setInterval =>
    console.log @node.resources.data
  ,5000

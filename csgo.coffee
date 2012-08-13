nodelay = require './nodelay'

nodelay "single-origin-roasters", ->
  @upstream "1.2.3.4"
  @proxy  "metric", "up", "down"


  @workers "process"
  @monitors "process"
  @controllers "csgo"

  @resource "simple"
    start: "coffee test/daemons/simple.coffee"
    pidFile: "pidfile.pid"


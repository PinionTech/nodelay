service = require '../service'
monitor = require '../monitor'

service "simple"
  start: "coffee daemons/simple.coffee"
  checks: ->
    @warn  "cpu" if @cpuUsage > 0.7
    @alert "cpu" if @cpuUsage > 0.9

service "spinner"
  start: "coffee daemons/spinner.coffee"
  checks: ->
    console.log "check running", @
    @warn  "cpu" if @cpuUsage > 0.7
    @alert "cpu" if @cpuUsage > 0.9



monitor service.allServices
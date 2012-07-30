service = require '../service'
monitor = require '../monitor'

service "simple"
  start: "coffee daemons/simple.coffee"

service "spinner"
  start: "coffee daemons/spinner.coffee"

monitor service.allServices
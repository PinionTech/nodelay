service = require '../service'

s = service "simple"
  start: "coffee daemons/simple.coffee"
  stop: (s) -> "kill #{s.pid}"

console.log "starting simple"
s.start ->

console.log "simple started"

#setTimeout ->
console.log "stopping simple"
s.stop()
#, 2000
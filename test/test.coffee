service = require '../service'

s = service "simple"
  start: "coffee daemons/simple.coffee"
  stop: (s) -> "kill -- -#{s.pid}"


s2 = service "simple2"
  start: "coffee daemons/simple.coffee"
  stop: (s) -> "kill -- -#{s.pid}"

console.log "starting simple"
s.start()
console.log "simple started", s.pid

console.log "starting simple2"
s2.start()
console.log "simple2 started", s2.pid


setTimeout ->
  console.log "stopping simple"
  s.stop()
  console.log "simple stopped"

  console.log "stopping simple2"
  s2.stop()
  console.log "simple2 stopped"
, 200000000
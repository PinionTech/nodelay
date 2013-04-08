{onlyChanges, deepMerge, deepDelete} = require './resource'

class ObjClock
  constructor: ->
    @clocks = []
    @clock = {}
    @addClock {}, {}

  addClock: (obj, clock) ->
    val = {obj, clock}
    @clocks.push val
    val

  removeClock: (i) ->
    @clocks.splice(i, 1) unless i is 0

  clockDominates: (oldc, newc) ->
    newer = false
    for node, oldver of oldc
      newver = newc[node]
      #console.log "checking", node, "old", oldver, "against new", newver
      return false if !newver? or newver < oldver
      newer = true if newver > oldver

    for node, newver of newc
      newer = true if !oldc[node]

    return newer

  clockPrune: (c1, c2) ->
    for node of c2 when c1[node]
      delete c1[node] if c1[node] <= c2[node]
    return true

  mergeClock: (c) ->
    for node, ver of c
      @clock[node] = ver if ver > @clock[node]

  inc: (name) ->
    @clock[name] ?= 0
    @clock[name]++

  update: (newobj, _newclock) ->
    newobj = JSON.parse JSON.stringify newobj
    newclock = {}
    newclock[k] = v for k, v of _newclock
    #console.log "newobj", newobj, "with clock", newclock
    for {obj, clock}, i in @clocks.slice()
      if @clockDominates clock, newclock
        # console.log "wins against", obj, "with clock", clock
        emptied = deepDelete obj, newobj
        # console.log "(old object pruned)"
        @removeClock i if emptied
      else
        # console.log "loses against", obj, "with clock", clock
        emptied = deepDelete newobj, obj
        # console.log "(update pruned)" if emptied
        return null if emptied
        @clockPrune newclock, clock

    @mergeClock newclock
    return @addClock newobj, newclock

module.exports = ObjClock

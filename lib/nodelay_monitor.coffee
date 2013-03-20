fs = require 'fs'
toobusy = require 'toobusy'

UPDATE_INTERVAL = 15000

diff = (a, b) -> (a - b) / (UPDATE_INTERVAL / 1000)

round3 = (x) -> Math.round(x*1000)/1000

qw = (s) -> s.split /\s+/

class NodelayMonitor
  constructor: (nodelay) ->
    return new NodelayMonitor nodelay if this is global
    @nodelay = nodelay

    @node = @nodelay.node
    @resource = @node.resources.sub "nodelay"

    @resource.update {
      auth: !!@node.auth
      bind: @nodelay.bind
      port: @nodelay.port
      controllers: @nodelay.controllers
      monitors: @nodelay.monitors
      workers: @nodelay.workers
      pid: process.pid
    }

    @currentUpdate = {}
    @rates = {}

    setTimeout @update, 0
    setInterval @update, UPDATE_INTERVAL

  flush: ->
    @resource.update @currentUpdate
    @currentUpdate = {}

  update: =>
    @updateRates()
    @updateStats()
    @updateByNode()
    @updateUsage()
    @updateLag()
    @updateVClock()
    @flush()

  updateLag: ->
    @currentUpdate.lag = toobusy.lag()

  updateUsage: ->
    # Todo: probably pull this out and just use the standard service monitor
    @currentUpdate.mem_usage = process.memoryUsage()
    fs.readFile "/proc/#{process.pid}/stat", 'utf8', (err, data) =>
      return if err # We probably don't have procfs
      vals = data.split(' ')
      ticks = parseInt(vals[13]) + parseInt(vals[14]) # utime + stime
      if @oldTicks
        timediff = (new Date() - @oldDate) / 1000
        # 100 Jiffies per second, ticks measured in jiffies
        usage = (ticks - @oldTicks) / (100 * timediff)
        @currentUpdate.cpu_usage = Math.round(usage*1000)/1000

      @oldTicks = ticks
      @oldDate = new Date()

  updateStats: ->
    for stat in qw "connections listeners"
      @currentUpdate[stat] = @node.stats[stat]

  updateRates: ->
    for rate in qw "in out connect disconnect discard"
      @currentUpdate[rate+"_rate"] = round3(diff(@node.stats[rate], @rates[rate])) if @rates[rate]
      @rates[rate] = @node.stats[rate]

  updateByNode: ->
    @currentUpdate.by_node ?= {}

    for name, node of @node.stats.by_node
      update = @currentUpdate.by_node[name] ?= {}

      update[stat] = node[stat] for stat in qw "listeners" when node[stat]?

      for rate in qw "in"
        ratename = "#{name}.#{rate}"
        update[rate+"_rate"] = round3(diff(node[rate], @rates[ratename])) if @rates[ratename]
        @rates[ratename] = node[rate]

  updateVClock: ->
    @currentUpdate.vclock = @node.objclock.clock

module.exports = NodelayMonitor
fs = require 'fs'

UPDATE_INTERVAL = 15000

diff = (a, b) -> (a - b) / (UPDATE_INTERVAL / 1000)

round3 = (x) -> Math.round(x*1000)/1000

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

    setTimeout =>
      @updateRates()
      @updateUsage()
    , 0

    setInterval =>
      @updateRates()
      @updateUsage()

    , UPDATE_INTERVAL

  updateUsage: ->
    # Todo: probably pull this out and just use the standard service monitor
    @resource.update mem_usage: process.memoryUsage()
    fs.readFile "/proc/#{process.pid}/stat", 'utf8', (err, data) =>
      return if err # We probably don't have procfs
      vals = data.split(' ')
      ticks = parseInt(vals[13]) + parseInt(vals[14]) # utime + stime
      if @oldTicks
        timediff = (new Date() - @oldDate) / 1000
        # 100 Jiffies per second, ticks measured in jiffies
        usage = (ticks - @oldTicks) / (100 * timediff)
        @resource.update cpu_usage: Math.round(usage*1000)/1000

      @oldTicks = ticks
      @oldDate = new Date()

  updateRates: ->
    if @rates
      @resource.update in_rate: round3(diff(@node.stats.in, @rates.in)), out_rate: round3(diff(@node.stats.out, @rates.out))
    @rates = in: @node.stats.in, out: @node.stats.out


module.exports = NodelayMonitor
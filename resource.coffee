class Resource extends EventEmitter
  constructor: (name, opts={}) ->
    return (new Resource name, opts) if this is global
    
    [@name, @opts] = [name, opts]

    for k in "".split ' '
      @[k] = @opts[k] if @opts[k]?

    
    @metrics = {}
    addMetric name for name of @opts.metrics

  addMetric: (name) ->
    metric = new Metric name
    @metrics[name] = metric
    metric.on "change" =>
      @emit name, @value, @metadata

class Metric extends EventEmitter
  historySize = 5

  constructor: (@name) ->
    @updated = null
    @changed = null
    @history = []

  update: (value, @metadata={}) ->
    time = new Date()
    @updated = time

    @history.push value: value, time: time
    @history.splice(@historySize)

    changed = (@value == value)
    @value = value
    
    if changed
      @changed = time
      @emit "change", @value, @metadata
      



module.exports = Resource
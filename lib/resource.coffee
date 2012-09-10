EventEmitter = require('events').EventEmitter

jsondiffpatch = require 'jsondiffpatch'


onlyChanges = (older, newer) ->
  # Too hard basket
  return newer if older instanceof Array or newer instanceof Array

  obj = {}
  changed = false
  for k of older 
    if typeof older[k] is 'object' and typeof newer[k] is 'object'
      changes = onlyChanges older[k], newer[k]
      if changes
        obj[k] = changes
        changed = true
    else
      if newer[k] != older[k]        
        obj[k] = newer[k]
        changed = true
  for k of newer
    unless obj[k]? or older[k]?
      obj[k] = newer[k]
      changed = true

  if changed then obj else null


class Resource
  constructor: (name, node, data) ->
    return new Resource(name, node) if this is global

    this[k] = v for k, v of data
    [@name, @node] = [name, node]

    listeners = []

  on: (ev, fn) ->
    cb = (msg) =>
      fn(msg) if msg.resource is @name
    @node.on ev, cb
    listeners.push {ev, cb}

  metric: (metric) ->
    if !@oldMetric
      @send 'metric', metric
    else
      #console.log "diff", @oldmetric, metric
      changes = jsondiffpatch.diff @oldMetric, metric
      #changes = onlyChanges @oldMetric, metric
      @send 'metric', changes
    #@oldMetric = metric

  send: (type, data) ->
    msg = @node.buildMsg type, data
    msg.resource = @name
    @node.send msg

  cleanup: ->
    @node.removeListener ev, cb for {ev, cb} in listeners
    listeners = []

module.exports = Resource











class Resource
  constructor: (node, data) ->
    return new Resource(name, node) if this is global
    [@node, @data] = [node, data]





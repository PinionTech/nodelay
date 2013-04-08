EventEmitter = require('events').EventEmitter

MsgEmitter = require './msgemitter'
jsondiffpatch = require 'jsondiffpatch'


onlyChanges = (older, newer) ->
  # Too hard basket
  return newer if (older instanceof Array or newer instanceof Array) and older.length != newer.length

  return (if newer == older then null else newer) if typeof older isnt 'object' or typeof newer isnt 'object' or !older or !newer

  obj = if older instanceof Array then [] else {}
  changed = false
  for k of newer
    if typeof older[k] is 'object' and typeof newer[k] is 'object'
      changes = onlyChanges older[k], newer[k]
      if changes
        obj[k] = changes
        changed = true
      else if older instanceof Array
        if newer[k] instanceof Array
          obj[k] = newer[k]
        else
          obj[k] = {}
    else
      if newer[k] != older[k]
        obj[k] = newer[k]
        changed = true
      else if older instanceof Array
        obj[k] = newer[k]

  if changed then obj else null

deepMerge = (dst, src) ->
  # Can't merge different-length arrays, but we zero-length it so we preserve the reference
  dst.length = 0 if dst instanceof Array and src instanceof Array and dst.length != src.length

  for k, srcv of src
    dstv = dst[k]
    if srcv is null
      delete dst[k]
    else if typeof dstv is 'object' and typeof srcv is 'object'

      # Merging two arrays
      if (dstv instanceof Array) and (srcv instanceof Array) and dstv.length == srcv.length
        deepMerge dstv, srcv

      # Merging two objects
      else if dstv isnt null and (dstv not instanceof Array) and (srcv not instanceof Array)
        deepMerge dstv, srcv

      else
        dst[k] = srcv
    else
      dst[k] = srcv
  return

deepDelete = (dst, src) ->
  return unless src
  emptied = true
  for k, dstv of dst

    srcv = src[k]
    if srcv is null
      delete dst[k]
    else if typeof dstv is 'object' and typeof srcv is 'object'
      if ((dstv instanceof Array) and (srcv instanceof Array) and dstv.length == srcv.length) or
        ((dstv not instanceof Array) and (srcv not instanceof Array))
          subemptied = deepDelete dstv, srcv
          if subemptied
            delete dst[k]
          else
            emptied = false
      else
        delete dst[k]
    else if srcv isnt undefined
      delete dst[k]
    else
      emptied = false

  return emptied

clobber = (dst, src) ->
  delete dst[k] for k, v of dst
  dst[k] = src[k] for k, v of src


matches = MsgEmitter.matches

class Resource
  constructor: (@node, @path, @data) ->

  at: (path) ->
    cur = @data
    path = Array.prototype.slice.apply(arguments) if typeof path is 'string'
    for comp in path
      cur = cur[comp]
      return null unless cur?

    new Resource @node, @path.concat(path), cur


  sub: (path) ->
    #console.log "descending from ", @path, "into", path
    cur = @data
    #console.log "data is", @data
    #console.log "@#*@&#(@*%" if @data[0]
    path = Array.prototype.slice.apply(arguments) if typeof path is 'string'

    for comp in path
      cur[comp] ||= {}
      cur = cur[comp]

    new Resource @node, @path.concat(path), cur

  merge: (data, clock, source) ->
    # This doesn't deal properly with simple values (ie can't merge numbers or bools if that's the entire contents of the resource)
    # We could probably do this by ascending one level up the tree and replacing the data
    # But that sounds hard and I don't need the functionality for anything

    # Oops
    #return deepMerge @data, data

    scopedData = @fullForm data

    newoc = @node.objclock.update scopedData, clock
    if newoc
      source = source.join('\x1f') if source instanceof Array
      newoc.source = source if source
      obj = @fromFullForm JSON.parse JSON.stringify newoc.obj
      deepMerge @data, obj

  update: (data) ->
    name = @node.name.join?('\x1f') or @node.name
    @node.objclock.inc name
    @sendUpdate data
    @merge data, @node.objclock.clock, @node.name

  # This might need some serious optimisation
  snapshotMatch: (matcher, opts={}) ->
    if matches @data, matcher
      @snapshot opts
   
    for name, resource of @data
      if typeof resource is 'object'
        sub = @at(name)
        sub?.snapshotMatch(matcher, opts) or false

  snapshot: (opts={}) ->
    opts.scope = 'link'
    opts.snapshot = true
    
    #console.log "snapshotting", @path
    for {obj, clock} in @node.objclock.clocks
      update = @fromFullForm obj
      if update
        #console.log "scoped clock", clock, "update", update 
        opts.vclock = clock
        @sendUpdate update, opts

  sendUpdate: (data, opts={}) ->
    msg = {}
    msg[k] = v for k, v of opts
    msg.type = "resource update"
    msg.vclock ||= @node.objclock.clock

    if opts.snapshot
      msg.data = data
    else
      msg.data = onlyChanges @data, data

    return if !msg.data


    #msg.data = onlyChanges data
    @send msg

  send: (type, data) ->
    msg = @node.buildMsg type, data
    msg.resource = @path
    if msg.parentonly
      @node.parent.send msg
    else
      @node.send msg

  on: (selector, cb) ->
    resMatcher = {}
    if typeof selector is 'object'
      resMatcher[k] = v for k, v of selector
    else if typeof selector is 'string'
      resMatcher.type = selector
    else
      console.warn "Invalid selector", selector

    resMatcher.resource = @path

    @node.on resMatcher, (msg) => cb this, msg

  watch: (updateCB) ->
    @updateCB = updateCB if updateCB
    #console.log @node.name, "listening for resource updates on", @path
    @node.on {type: "resource update", resource: @path}, @handleResourceUpdate
    #@node.on {type: "resource update request", resource: @path}, @handleUpReq

  scopePath: (path) ->
    for component, i in @path
     #console.log "comparing", path[i], "with", component
     break unless path[i] == component
    path.slice(i)

  fullForm: (data) ->
    scopedData = data or @data
    for p in @path.slice().reverse()
      oldData = scopedData
      scopedData = {}
      scopedData[p] = oldData
    scopedData

  fromFullForm: (data) ->
    cur = data
    for comp in @path
      cur = cur[comp]
      return null unless cur?
    cur

  handleResourceUpdate: ({resource, data, from, vclock}) =>
    #console.log @node.name, "got resource update for", resource, data
    #console.log "from", from, "vclock", vclock unless from and vclock
    return unless from and vclock
    resource ||= []
    path = @scopePath resource
    res = @sub path
    res.merge data, vclock, from

    scopedData = data
    for p in path.slice().reverse()
      oldData = scopedData
      scopedData = {}
      scopedData[p] = oldData

    @updateCB? this, scopedData
    res

  handleUpReq: ({resource, data, scope, from}) =>
    res = @at @scopePath resource
    opts = {}
    opts.scope = 'link' if scope is 'link'
    opts.to = from
    res?.snapshot(opts)


class Selector
  constructor: (@node, selector, @updateCB) ->
    matcher = {type: "resource update", resource: selector}

    #console.log @node.name, "listening for", matcher
    @node.on matcher, @handleMatchUpdate

    @resources = {}
    @matchedResources = {}
    @matchers = []

  handleMatchUpdate: ({resource, data}) =>
    resource = [resource] if typeof resource is 'string'
    resource ||= []
    strForm = resource.join '\x1f'
    if !@matchedResources[strForm]
      #console.log @node.name, "adding new resource", resource
      res = @node.resources.sub resource
      res.watch(@updateCB)
      #res.send type: "resource update request", scope: 'link'
      res.handleResourceUpdate {resource, data}

      @matchedResources[strForm] = res

      for {matcher, cb} in @matchers
        res.on matcher, cb

  on: (matcher, cb) ->
    @matchers.push {matcher, cb}
    for path, res of @matchedResources
      res.on matcher, cb

  each: (cb) ->
    for path, res of @matchedResources
      cb res.path, res

Resource[k] = v for k, v of {Selector, onlyChanges, deepMerge, clobber, matches, deepDelete}

module.exports = Resource

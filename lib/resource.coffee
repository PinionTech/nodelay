EventEmitter = require('events').EventEmitter

jsondiffpatch = require 'jsondiffpatch'


onlyChanges = (older, newer) ->
  # Too hard basket
  return newer if (older instanceof Array or newer instanceof Array) and older.length != newer.length

  obj = if older instanceof Array then [] else {}
  changed = false
  for k of newer
    if typeof older[k] is 'object' and typeof newer[k] is 'object'
      changes = onlyChanges older[k], newer[k]
      if changes
        obj[k] = changes
        changed = true
      else if older instanceof Array
        obj[k] = new newer[k].constructor
    else
      if newer[k] != older[k]
        obj[k] = newer[k]
        changed = true
      else if older instanceof Array
        obj[k] = newer[k]

  if changed then obj else null



deepMerge = (dst, src) ->
  #console.log "deepmerging", src, "into", dst
  for k, srcv of src
    dstv = dst[k]
    if typeof dstv is 'object' and typeof srcv is 'object'
      deepMerge dstv, srcv
    else
      dst[k] = srcv

clobber = (dst, src) ->
  delete dst[k] for k, v of dst
  dst[k] = src[k] for k, v of src


# FIXME: This is a dupe from node.matches
matches = (obj, match) ->
  for k, matchv of match
    objv = obj[k]
    if typeof objv is 'object' and typeof matchv is 'object'
      return false unless matches objv, matchv
    else
      return false unless objv is matchv or (matchv is '*' and objv isnt undefined)
  
  return true


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

  merge: (data, merge="simple") ->
    switch merge
      when "simple" then deepMerge @data, data
      when "clobber" then clobber @data, data
      else console.warn "Unknown merge type", merge

  update: (data, merge) ->
    @sendUpdate data, merge
    @merge data, merge

  snapshotMatch: (matcher, opts={}) ->
    #console.log "snapshotMatching", matcher
    for name, resource of @data
      if matches resource, matcher
        #console.log "got match for", name
        sub = @at(name)
        #console.log "sub data is", sub.data
        sub.snapshot(opts)

  snapshot: (opts={}) ->
    opts.scope = 'link'
    #console.log "sending snapshot with data", @data
    @sendUpdate @data, "clobber", opts

  sendUpdate: (data, merge="simple", opts) ->
    msg = {}
    msg[k] = v for k, v of opts
    msg.type = "resource update"
    msg.merge = merge if merge

    switch merge
      when "simple" then msg.data = onlyChanges @data, data
      when "clobber" then msg.data = data
      else
        console.warn "Unknown merge type", merge
        msg.data = data

    #console.log @node.name, "Update message", msg

    return if !msg.data


    #msg.data = onlyChanges data
    @send msg

  send: (type, data) ->
    msg = @node.buildMsg type, data
    msg.resource = @path
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

  handleResourceUpdate: ({resource, merge, data}) =>
    #console.log @node.name, "got resource update for", resource, data
    resource ||= []
    path = @scopePath resource
    res = @sub path #@scopePath resource
    res.merge data, merge

    @updateCB? this, @data #res, msg.data
    res

  handleUpReq: ({resource, merge, data, scope, from}) =>
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

  handleMatchUpdate: ({resource, merge, data}) =>
    resource = [resource] if typeof resource is 'string'
    resource ||= []
    strForm = resource.join '\x1f'
    if !@matchedResources[strForm]
      #console.log @node.name, "adding new resource", resource
      res = @node.resources.sub resource
      res.watch(@updateCB)
      res.send type: "resource update request", scope: 'link'
      res.handleResourceUpdate {resource, merge, data}

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

Resource.Selector = Selector

module.exports = Resource

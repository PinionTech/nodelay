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



deepMerge = (dst, src) ->
  for k, srcv of src
    dstv = dst[k]    
    if typeof dstv is 'object' and typeof srcv is 'object'
      deepMerge dstv, srcv
    else
      dst[k] = srcv

clobber = (dst, src) ->
  delete dst[k] for k, v of dst
  dst[k] = src[k] for k, v of src



class Resource
  constructor: (@node, @path, @data) ->

  check: (path) ->
    cur = @data
    path = Array.prototype.slice.apply(arguments) if typeof path is 'string'
    for comp of path
      cur = cur[comp]
      return null unless cur?
    
    new Resource @node, @path.concat(path), cur


  sub: (path) ->
    cur = @data
    path = Array.prototype.slice.apply(arguments) if typeof path is 'string'
    for comp of path
      cur[comp] ||= {}
      cur = cur[comp]
    
    new Resource @node, @path.concat(path), cur

  merge: (data, merge="simple") ->
    switch merge
      when "simple" then deepMerge @data, data
      when "clobber" then clobber @data, data
      else console.warn "Unknown merge type", merge

  update: (data, merge) ->
    @merge data, merge
    @sendUpdate data, merge

  snapshot: ->
    sendUpdate @data

  sendUpdate: (data, merge) ->
    # TODO: onlyChanges/diff/patch
    if merge
      @send type: "resource update", merge: merge, data: data
    else
      @send "resource update", data

  send: (type, data) ->
    msg = @node.buildMsg type, data
    msg.resource = @path
    @node.send msg

  on: (selector, cb) ->
    resMatcher = {}
    resMatcher[k] = v for k, v of matcher
    resMatcher.resource = @path

    resMatcher.resource = @path

    @node.on resMatcher, (msg) => cb this, msg

  watch: (@updateCB) ->
    @node.on {type: "resource update", @path}, @handleResourceUpdate
    @node.on {type: "resource update request", @path}, @handleUpReq

  scopePath: (path) ->
    for i, component in @path
      break unless path[i] == component
    path.slice(i)

  handleResourceUpdate: ({resource, merge, data}) =>      
    res = @sub @scopePath resource
    res.merge data, merge
    @updateCB res, data

  handleUpReq: ({resource, merge, data}) =>
    res = @check @scopePath resource
    res?.snapshot()


class Selector
  constructor: (@node, selector, @updateCB) ->
    selector.type = "resource update"
    @node.on selector, @handleMatchUpdate

    @resources = {}
    @matchedResources = {}
    @matchers = []

  handleMatchUpdate: ({resource, merge, data}) =>
    resource = [resource] unless typeof resource is 'string'
    strForm = resource.join '\x1f'
    if !@matchedResources[strForm]
      res = @node.resources.sub resource
      res.watch(@updateCB)
      res.onResourceUpdate {resource, merge, data}

      @matchedResources[strForm] = res

      for {matcher, cb} in matchers
        res.on matcher, cb

  on: (matcher, cb) ->
    matchers.push {matcher, cb}
    for path, res of @matchedResources
      res.on matcher, cb

  each: (cb) ->
    for path, res of @matchedResources
      cb res.path, res

Resource.Selector = Selector

module.exports = Resource

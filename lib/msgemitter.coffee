_ = require 'underscore'

msgMatches = (msg, match, resources) ->
  for k, matchv of match
    objv = msg[k]
    if typeof objv is 'object' and typeof matchv is 'object' and k isnt 'resource'
      return false unless matches objv, matchv
    else if k is 'resource'
      #console.log "matching resource", objv, matchv, (typeof matchv), (not (matchv instanceof Array))
      if typeof matchv is 'object' and not (matchv instanceof Array)
        resource = resources?.at(msg.resource or [])
        return false unless resource

        return false unless matches resource.data, matchv
      else if objv instanceof Array
        return false unless matchArrayHead matchv, objv
      else
        return false
    else
      return false unless objv is matchv or matchv is '*'
  
  return true

matches = (obj, match) ->
  for k, matchv of match
    objv = obj[k]
    if typeof objv is 'object' and typeof matchv is 'object'
      return false unless matches objv, matchv
    else
      return false unless objv is matchv or (matchv is '*' and objv isnt undefined)
  
  return true

matchArrayHead = (matcher, matchee) ->
  return false if !matchee
  matcher = [matcher] if typeof matcher is 'string'
  matchee = [matchee] if typeof matchee is 'string'
  for res, i in matcher
    return false if matchee[i] isnt res
  return true



class MatchIndex
  constructor: ->
    @matchsets = []
  
  add: (matchset) ->
    @matchsets.push matchset

  find: (matcher) ->
    for matchset in @matchsets when matchset.hasMatcher matcher
      return matchset
    return null

  remove: (matchset) ->
    j = @matchsets.indexOf matchset
    @matchsets.splice j, 1 if j >= 0

  each: (cb) ->
    cb matchset for matchset in @matchsets
  
  fire: (msg, resources) ->
    matchset.fire msg, resources for matchset in @matchsets
    return





class MatchSet
  constructor: (@matcher) ->
    @cbs = []
  
  add: (cb) ->
    @cbs.push cb

  remove: (cb) ->
    j = @cbs.indexOf cb
    @cbs.splice j, 1 if j >= 0

  length: -> @cbs.length
  empty: -> @cbs.length == 0

  fire: (msg, resources) ->
    if msgMatches msg, @matcher, resources
      cb(msg) for cb in @cbs

  hasMatcher: (matcher) -> _.isEqual @matcher, matcher



class MsgEmitter
  indexAttribs: ['scope', 'type']

  on: (matcher, cb) ->
    matcher = {type: matcher} if typeof matcher is 'string'

    @cache ||= {}

    @all ?= new MatchIndex
    if !@indices
      @indices = {}
    
    matchset = @all.find matcher
    if !matchset
      matchset = new MatchSet(matcher)
      @all.add matchset
      for attrib in @indexAttribs
        if (val = matcher[attrib])? and val isnt '*'
          #console.log "adding index for", attrib, "=", val
          @addIndex attrib, val, matchset
      
      if typeof matcher.resource is 'object' and matcher.resource.constructor is Array and matcher.resource[0]
        @addIndex 'resource', matcher.resource[0], matchset

    
    matchset.add cb

    return

  addIndex: (attrib, val, matchset) ->
    @indices[attrib] ||= {}
    @indices[attrib][val] ||= new MatchIndex()
    @indices[attrib][val].add matchset


  removeListener: (cb) ->
    return unless @all
    
    remove = []
    @all.each (matchset) ->
      matchset.remove(cb)
      if matchset.empty()
        remove.push matchset

    for matchset in remove
      @all.remove matchset
      for k, index2 of @indices
        for k, index of index2
          index.remove matchset
    return

  removeAllListeners: ->
    @all = null
    @cache = null
  
  emit: (msg) ->
    return unless @all

    for attrib in @indexAttribs
      if (val = msg[attrib])? and val isnt '*'
        #console.log "emitting on index", attrib, val, @indices[attrib][val]?.matchsets.length
        @indices[attrib][val]?.fire msg, @node?.resources
        return


    if val = msg.resource?[0]
      @indices.resource[val].fire msg, @node?.resources
      return
    
    @all.fire msg, @node?.resources
    return

MsgEmitter[k] = v for k, v of {matches,msgMatches,matchArrayHead}

module.exports = MsgEmitter
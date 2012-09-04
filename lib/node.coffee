jsondiffpatch = require 'jsondiffpatch'
crypto = require 'crypto'
EventEmitter = require('events').EventEmitter
ws = require 'ws'
_ = require 'underscore'

HASH_ALG = 'sha256'

extend = (foo, bar) -> foo[k] = v for own k, v of bar


matches = (obj, match) ->
  for k, matchv of match
    objv = obj[k]
    if typeof objv is 'object' and typeof matchv is 'object'
      return false unless matches objv, matchv
    else
      return false unless objv is matchv or matchv is '*'
  
  return true



class MsgEmitter
  on: (matcher, cb) ->
    matcher = {type: matcher} if typeof matcher is 'string'

    @listeners ?= []
    
    for listener in @listeners
      return listener.cbs.push cb if _.isEqual listener.matcher, matcher

    @listeners.push {matcher, cbs:[cb]}

  removeListener: (cb) ->
    return unless @listeners
    remove = []
    for listener, i in @listeners
      i = indexOf cb, listener.cbs
      listener.cbs.splice i, 1 if i >= 0
      remove.push i

    @listeners.splice i, 1 for i in remove

  removeAllListeners: -> @listeners = []
  
  emit: (msg, args...) ->
    return unless @listeners
    for listener in @listeners
      #console.log "msg", msg
      #console.log "matcher", listener.matcher
      #console.log "matches?", matches msg, listener.matcher
      if matches msg, listener.matcher
        cb(msg, args...) for cb in listener.cbs

class Node extends MsgEmitter
  @connect = (args...) -> Node().connect args...
  @listen = (args...) -> Node().listen args...
  
  constructor: (name) ->
    return new Node(name) if this is global

    @name = name or Math.random().toFixed(10).slice(2)

    @parent = new MsgEmitter
    extend @parent,
      send: (type, data) => @parent.sendRaw @buildMsg type, data
      sendRaw: (msg) =>
        if @ws and @ws.readyState == 1
          @ws.send JSON.stringify msg
      forward: (msg) => @parent.sendRaw msg

    @children = new MsgEmitter
    extend @children, 
      send: (type, data) => @children.sendRaw @buildMsg type, data
      sendRaw: (msg) =>
        if @wss
          if @auth
            client.send JSON.stringify msg for client in @wss.clients when client.authed
          else
            client.send JSON.stringify msg for client in @wss.clients
      forward: (msg) => @children.sendRaw msg

    @resources = {}

  connect: (host, port=44445, cb) -> 
    [port, cb] = [44445, port] if typeof port is 'function'
    [@host, @port, @cb] = [host, port, cb]
    
    console.log @name, "connecting to", host, "on", port
    @ws = new ws("ws://#{host}:#{port}")
    @ws.on 'message', (data) => @recv data, @ws
    @ws.on 'open', cb if cb
    @ws.on 'close', =>
      console.log @name, "connection closed"
      @reconnect()
    @ws.on 'error', (err) =>
      console.log @name, "error", err.message
      @reconnect()
    this
  
  reconnect: =>
    console.log @name, "reconnecting in 5s"
    setTimeout =>
      @connect @host, @port, @cb
    , 5000
  
  listen: (host="127.0.0.1", port=44445, cb) ->
    [port, cb] = [44445, port] if typeof port is 'function'
    console.log @name, "listening on", host, "port", port
    @wss = new ws.Server({host, port})
    @wss.on 'connection', (client) =>
      if @auth and client._socket.remoteAddress == '127.0.0.1'
        client.authed = true
      cb?()
      #if @auth and 
      client.on 'message', (data) => @recv data, client
    this
   
  sendRaw: (msg) ->
    @parent.sendRaw msg
    @children.sendRaw msg

  forward: (msg) => @sendRaw msg

  buildMsg: (type, data={}) ->
    if typeof type is "string"
      msg = {type, data}
    else
      msg = type    
    msg.from ||= @name
    msg.time = new Date().toISOString()
    
    if msg.signed and @privkey
      signer = crypto.createSign HASH_ALG
      signer.update JSON.stringify msg
      msg.signature = signer.sign @privkey, 'base64'
    msg

  send: (type, data) -> @sendRaw @buildMsg type, data

  recv: (data, sender) =>
    msg = JSON.parse data

    from = if typeof msg.from is 'object' then msg.from[0] else msg.from
    to   = if typeof msg.to is 'object' then msg.to[0] else msg.to
    
    return if from is @name
    return if to and to isnt @name
 
    if msg.signed
      signature = msg.signature
      delete msg.signature
      if !@pubkey
        msg.signed = false
      else
        verifier = crypto.createVerify HASH_ALG
        verifier.update JSON.stringify msg
        msg.signed = verifier.verify @pubkey, signature, 'base64'  

    if @auth and sender and !sender.authed
      if msg.type is "auth" and msg.signed and @auth msg.data
        sender.authed = true
      else
        sender.close()
        return


    @emit msg
    specific = if sender is @ws then @parent else @children
    specific.emit msg

  resource: (name, data) ->
    @resources[name] ||= new Resource name, this, data
    @resources[name]

  unresource: (name) ->
    if @resources[name]
      @resources[name].cleanup()
      delete @resources[name]


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



module.exports = Node

crypto = require 'crypto'
EventEmitter = require('events').EventEmitter
ws = require 'ws'
_ = require 'underscore'

Resource = require './resource'

HASH_ALG = 'sha256'

extend = (foo, bar) -> foo[k] = v for own k, v of bar


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
      j = listener.cbs.indexOf cb
      listener.cbs.splice j, 1 if j >= 0
      remove.push i if listener.cbs.length is 0

    @listeners.splice i, 1 for i in remove

  removeAllListeners: -> @listeners = []
  
  eachMatcher: (cb) ->
    cb listener.matcher for listener in @listeners

  eachListener: (cb) ->
    return unless @listeners
    for listener in @listeners
      for listenerCb in listener.cbs
        cb listener.matcher, listenerCb

  emit: (msg) ->
    return unless @listeners
    for listener in @listeners when msgMatches msg, listener.matcher, @node?.resources
      cb(msg) for cb in listener.cbs

class Parent extends EventEmitter
  constructor: (@node, host, port, cb) ->
    @listeners = {}
    @tag = 0
    @connect host, port, cb
    @matchers = {}

  connect: (@host, @port, @cb) ->
    console.log @node.name, "connecting to", @host, "on", @port
    @ws = new ws "ws://#{host}:#{port}"
    @ws.on 'message', (data) => @recv data, @ws
    @ws.on 'open', =>
      @node.send type: 'auth', signed: true, scope: 'link' if @node.privkey
      @node.send type: 'name', scope: 'link', data: @node.name

      for tag, matcher of @matchers
        @send type: "listen", scope: "link", data: matcher, tag: tag
      
      # This should be in Resource via a listener or such
      for name, data of @node.resources.data
        @send type: "resource update", resource: name, data: data
      
      ping = true
      @pingInterval = setInterval =>
        if ping is false
          console.log @node.name, "ping timed out to parent"
          @ws.close()

        ping = false
        @send type: 'ping', scope: 'link'
      ,5000
      @on type: 'pong', scope: 'link', -> ping = true
      @cb() if @cb

    @ws.on 'close', =>
      clearInterval @pingInterval
      console.log @node.name, "connection closed"
      @reconnect()

    @ws.on 'error', (err) =>
      console.log @node.name, "error", err.message
      @reconnect()

    this
  
  reconnect: =>
    console.log @node.name, "reconnecting in 5s"
    setTimeout =>
      @connect @host, @port, @cb
    , 5000

  send: (type, data) =>
    msg = @node.buildMsg type, data
    @sendRaw msg

  sendRaw: (msg) =>
    #console.log "child", @node.name, "msg before", msg
    msg = @outFilter msg if @outFilter
    return unless msg
    #console.log "child", @node.name, "msg after", msg
    if @ws and @ws.readyState == 1
      #console.log "child", @node.name, "sending", msg
      @ws.send JSON.stringify msg
    else
      #console.log @node.name, "dropping message", msg

  forward: (msg) => @sendRaw msg

  recv: (data, client) =>
    msg = @node.processMsg data, client
    msg = @inFilter msg if @inFilter
    return unless msg
    tag = msg.tag
    delete msg.tag
    @emit tag, msg

  on: (matcher, cb) ->
    tag = @tag++
    super tag, cb
    @matchers[tag] = matcher
    @send type: "listen", scope: "link", data: matcher, tag: tag

  #TODO: removeListener, removeAllListeners (should invalidate @matchers)


class Children extends MsgEmitter
  constructor: (@node, host, port, cb) ->
    @listeners = []
    @outEmitter = new MsgEmitter
    @outEmitter.node = @node
    @listen host, port, cb

  listen: (@host, @port, cb) ->
    console.log @node.name, "listening on", host, "port", port
    @on type: 'ping', scope: 'link', (msg) => @send type: 'pong', scope: 'link', to: msg.from

    @wss = new ws.Server {host, port}
    @wss.on 'connection', (client) =>
      if @node.auth and client._socket.remoteAddress == '127.0.0.1'
        client.authed = true
      cb?()
      client.on 'message', (msg) => @recv msg, client

      client.nodelay_listeners = []
      client.on 'close', =>
        for listener in client.nodelay_listeners
          @outEmitter.removeListener listener
    this

  recv: (data, client) =>
    #console.log "parent", @node.name, "received", data
    msg = @node.processMsg data, client
    return unless msg

    if @node.auth and !client.authed and (msg.type isnt 'listen' or msg.scope isnt 'link')
      if msg.type is "auth" and msg.signed and @node.auth msg
        console.log "accepted auth from", msg.from
        client.authed = true
        client.emit 'nodelay_auth'

      else
        console.log "rejected auth from", msg.from
        client.close()
        return

    client.name = msg.data if msg.type is "name" and msg.scope is 'link'

    @emit msg
    
    if msg.type is "listen"
      #console.log "got #{if client.authed then 'authed ' else ''}listen for", msg
      tag = msg.tag
      name = @node.name
      if msg.data.resource
        resource = msg.data.resource
        from = msg.from
        sendUpdate = =>
          if typeof resource is 'object' and resource not instanceof Array 
            @node.resources.snapshotMatch resource, to: from
          else
            @node.resources.at(resource)?.snapshot to: from

        if !@node.auth or client.authed
          #console.log "resource update (immediate) for matcher", resource
          sendUpdate()
        else if @node.auth
          #console.log "resource update (delayed) for matcher", resource
          client.once 'nodelay_auth', sendUpdate




      cb = (rmsg) =>
        #console.log "client authed?", client.authed
        return if client.readyState isnt 1
        return if @node.auth and !client.authed
        return if rmsg.to and !matchArrayHead rmsg.to, client.name

        rmsg = JSON.parse JSON.stringify rmsg
        rmsg.tag = tag
        client.send JSON.stringify rmsg
      
      @outEmitter.on msg.data, cb
      client.nodelay_listeners.push cb

  send: (type, data) => @sendRaw @node.buildMsg type, data
 
  sendRaw: (msg) ->
    #console.log "sendRawing", msg
    process.nextTick =>
      @outEmitter.emit msg

  forward: (msg) =>
    @sendRaw msg


class Node
  @connect = (args...) -> Node().connect args...
  @listen = (args...) -> Node().listen args...
  
  constructor: (name) ->
    return new Node(name) if this is global

    @name = name or Math.random().toFixed(10).slice(2)

    @resources = new Resource this, [], {}

  connect: (host, port=44445, cb) -> 
    [port, cb] = [44445, port] if typeof port is 'function'
    
    @parent = new Parent this, host, port, cb
    this
  
  listen: (host="127.0.0.1", port=44445, cb) ->
    [port, cb] = [44445, port] if typeof port is 'function'

    @children = new Children this, host, port, cb
    this
   
  sendRaw: (msg) ->
    @parent?.sendRaw msg
    @children?.sendRaw msg

  forward: (msg) => @sendRaw msg

  buildMsg: (type, data={}) =>
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

  processMsg: (data, sender) ->
    try
      msg = JSON.parse data
    catch e
      console.log "Error parsing message", data, e
      return

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

    msg

  send: (type, data) ->
    msg = @buildMsg type, data
    @parent?.sendRaw msg
    @children?.sendRaw msg

  on: (matcher, cb) =>
    @parent?.on matcher, cb
    @children?.on matcher, cb

  resource: (selector, cb) ->
    selector = [selector] if typeof selector is 'string'
    if typeof selector is 'object'
      if selector.constructor is Array
        @resources.sub selector
      else
        new Resource.Selector this, selector, cb


module.exports = Node

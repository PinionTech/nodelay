crypto = require 'crypto'
EventEmitter = require('events').EventEmitter
ws = require 'ws'
_ = require 'underscore'

Resource = require './resource'
MsgEmitter = require './msgemitter'
ObjClock = require './objclock'

HASH_ALG = 'sha256'

extend = (foo, bar) -> foo[k] = v for own k, v of bar


class Parent extends EventEmitter
  constructor: (@node, host, port, cb) ->
    @listeners = {}
    @tag = 0
    @connect host, port, cb
    @matchers = {}

  connect: (@host, @port, @cb) ->
    console.log @node.name, "connecting to", @host, "on", @port
    @ws?.close()
    @ws = new ws "ws://#{@host}:#{@port}"
    @ws.on 'message', (data) => @recv data, @ws

    @ws.on 'open', =>
      @node.send type: 'auth', signed: true, scope: 'link' if @node.privkey
      @node.send type: 'name', scope: 'link', data: @node.name

      @node.stats.by_node.parent ?= {in: 0}

      for tag, matcher of @matchers
        @send type: "listen", scope: "link", data: matcher, tag: tag

      # Do we still need to loop or can we just send one update for the whole lot?
      for name of @node.resources.data
        res = @node.resources.at name
        # Should be a better way of doing this. to: 'parent' or something?
        res.snapshot parentonly: true

      ping = true
      clearInterval @pingInterval
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
      clearInterval @pingInterval
      @reconnect()

    this

  reconnect: =>
    return if @reconnecting
    @reconnecting = true
    console.log @node.name, "reconnecting in 5s"
    setTimeout =>
      @connect @host, @port, @cb
      @reconnecting = false
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
    unless msg
      @node.stats.discarded++
      return

    @node.stats.in++
    @node.stats.by_node.parent.in++
    tag = msg.tag
    delete msg.tag
    @emit tag, msg

  on: (matcher, cb) ->
    tag = @tag++
    super tag, cb
    @matchers[tag] = matcher
    @send type: "listen", scope: "link", data: matcher, tag: tag

  removeListener: ->
  #TODO: removeListener, removeAllListeners (should invalidate @matchers)


class Children extends MsgEmitter
  constructor: (@node, host, port, cb) ->
    @listeners = []
    @outEmitter = new MsgEmitter
    @outEmitter.node = @node
    @listen host, port, cb

  listen: (@host, @port, cb) ->
    console.log @node.name, "listening on", @host, "port", @port
    @on type: 'ping', scope: 'link', (msg) => @send type: 'pong', scope: 'link', to: msg.from

    @wss = new ws.Server {host, port}
    @wss.on 'connection', (client) =>
      @node.stats.connect++
      @node.stats.connections++

      if @node.auth and client._socket.remoteAddress == '127.0.0.1'
        client.authed = true
      cb?()
      client.on 'message', (msg) => @recv msg, client

      client.nodelay_listeners = []
      client.on 'close', =>
        @node.stats.connections--
        @node.stats.disconnect++

        if client.name
          delete @node.stats.by_node[client.name]

          # XXX This should go somewhere else - probably within resource via an event listener
          for clock, i in @node.objclock.clocks.slice()
            if clock.source is client.name
              Resource.deepMerge @node.objclock.clocks[0].obj, clock.obj
              @node.objclock.removeClock i

          #delete @node.bynode[client.name]
          #@node.vclock.remove client.name
        else
          @node.stats.by_node.anonymous.listeners -= client.nodelay_listeners.length

        for listener in client.nodelay_listeners
          @outEmitter.removeListener listener

        @node.stats.listeners -= client.nodelay_listeners.length


    this

  recv: (data, client) =>
    #console.log "parent", @node.name, "received", data
    msg = @node.processMsg data, client
    unless msg
      @node.stats.discard++
      return
    @node.stats.in++
    #console.log "client name", client.name or "anonymous"
    @node.stats.by_node[client.name or "anonymous"]?.in++

    if @node.auth and !client.authed and (msg.type isnt 'listen' or msg.scope isnt 'link')
      if msg.type is "auth" and msg.signed and @node.auth msg
        console.log "accepted auth from", msg.from
        client.authed = true
        client.emit 'nodelay_auth'

      else
        console.log "rejected auth from", msg.from
        client.close()
        return

    if msg.type is "name" and msg.scope is 'link'
      client.name = msg.data
      @node.stats.by_node[client.name] = {in: 0, listeners: 0}

    @emit msg

    if msg.type is "listen"
      #console.log "got #{if client.authed then 'authed ' else ''}listen for", msg
      tag = msg.tag
      name = @node.name
      if msg.data.resource
        resource = msg.data.resource
        from = msg.from
        sendUpdate = =>
          if typeof resource is 'object' and !Array.isArray(resource)
            @node.resources.snapshotMatch resource, to: from
          else
            @node.resources.at(resource)?.snapshot to: from

        if !@node.auth or client.authed
          #console.log "resource update (immediate) for matcher", resource
          process.nextTick sendUpdate
        else if @node.auth
          #console.log "resource update (delayed) for matcher", resource
          client.once 'nodelay_auth', sendUpdate




      cb = (rmsg) =>
        #console.log "client authed?", client.authed
        return if client.readyState isnt 1
        return if @node.auth and !client.authed
        #console.log "TO:", rmsg.to, client.name, MsgEmitter.matchArrayHead(rmsg.to, client.name) if rmsg.to
        return if rmsg.to and !MsgEmitter.matchArrayHead rmsg.to, client.name

        rmsg.tag = tag
        client.send JSON.stringify rmsg
        delete rmsg.tag

      #console.log client.name, "listening for", msg.data
      @node.stats.by_node[client.name or "anonymous"]?.listeners++
      @node.stats.listeners++
      @outEmitter.on msg.data, cb
      client.nodelay_listeners.push cb

  send: (type, data) => @sendRaw @node.buildMsg type, data

  sendRaw: (msg) ->
    @node.stats.out++
    #console.log "sendRawing", msg if msg.type is 'resource update'
    process.nextTick =>
      @outEmitter.emit msg

  forward: (msg) =>
    @sendRaw msg


class Node
  @connect = (args...) -> Node().connect args...
  @listen = (args...) -> Node().listen args...

  constructor: (name) ->
    return new Node(name) if this is global

    @stats = {in: 0, out: 0, discard: 0, connect: 0, disconnect: 0, connections: 0, listeners: 0}
    @stats.by_node = {anonymous: {in: 0, listeners: 0}}

    @name = name or Math.random().toFixed(10).slice(2)

    @objclock = new ObjClock this
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

    if !@time
      @time = new Date().toISOString()
      setTimeout (=> @time = null), 1000

    msg.time = @time

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
    cb

  removeListener: (matcher, cb) =>
    @parent?.removeListener cb
    @children?.removeListener cb

  resource: (selector, cb) ->
    selector = [selector] if typeof selector is 'string'
    new Resource.Selector this, selector, cb

Node[k] = v for k, v of {MsgEmitter}

module.exports = Node

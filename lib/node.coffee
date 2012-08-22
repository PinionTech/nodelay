crypto = require 'crypto'
EventEmitter = require('events').EventEmitter

ws = require 'ws'

HASH_ALG = 'sha256'

class Node extends EventEmitter
  @connect = (args...) -> Node().connect args...
  @listen = (args...) -> Node().listen args...
  
  constructor: (name) ->
    return new Node(name) if this is global

    @name = name or Math.random().toFixed(10).slice(2)

  connect: (host, port=44445, cb) -> 
    [port, cb] = [44445, port] if typeof port is 'function'
    console.log @name, "connecting to", host, "on", port
    @ws = new ws("ws://#{host}:#{port}")
    @ws.on 'message', @recv
    @ws.on 'open', cb if cb
    this
  
  listen: (host="127.0.0.1", port=44445, cb) ->
    [port, cb] = [44445, port] if typeof port is 'function'
    console.log @name, "listening on", host, "port", port
    @wss = new ws.Server({host, port})
    @wss.on 'connection', (client) =>
      cb?()
      client.on 'message', (data) => @recv data, client
    this
   
  sendRaw: (msg) ->
    if @ws and @ws.readyState == 1
      @ws.send JSON.stringify msg
    if @wss
      if @auth
        client.send JSON.stringify msg for client in @wss.clients when client.authed
      else
        client.send JSON.stringify msg for client in @wss.clients

  forward: (msg) => @sendRaw msg

  parent:
    send: @send

  send: (type, data={}) ->
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
    
    @sendRaw msg 

  recv: (data, from) =>
    msg = JSON.parse data
 
    if msg.signed
      signature = msg.signature
      delete msg.signature
      if !@pubkey
        msg.signed = false
      else
        verifier = crypto.createVerify HASH_ALG
        verifier.update JSON.stringify msg
        msg.signed = verifier.verify @pubkey, signature, 'base64'  

    if @auth and from and !from.authed
      if msg.type is "auth" and msg.signed and @auth msg.data
        from.authed = true
      else
        from.close()
        return


    return if msg.from is @name
    return if msg.to and msg.to isnt @name
    @emit '*', msg
    if msg.type
      @emit msg.type, msg

module.exports = Node

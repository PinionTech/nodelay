EventEmitter = require('events').EventEmitter

ws = require 'ws'

class Node extends EventEmitter
  @connect = (args...) -> Node().connect args...
  @listen = (args...) -> Node().listen args...
  
  constructor: (name) ->
    return new Node(name) if this is global

    @name = name or Math.random().toFixed(10).slice(2)

  connect: (host, port=44445) -> 
    @ws = new ws("ws://#{host}:#{port}")
    @ws.on 'message', @recv
    this
  
  listen: (host="127.0.0.1", port=44445) ->
    console.log ws
    @wss = new ws.Server({host, port})
    @wss.on 'connection', (client) =>
      client.on 'message', @recv
    this
   
  sendRaw: (msg) ->
    if @ws
      @ws.send JSON.stringify msg
    if @wss
      client.send JSON.stringify msg for client in @wss.clients

  forward: (msg) => @sendRaw msg

  parent:
    send: @send
    sendRaw: @send

  send: (type, data={}) ->
    if typeof type is "string"
      msg = {type, data}
    else
      msg = type    
    msg.from ||= @name

    @sendRaw msg 

  recv: (data) =>
    msg = JSON.parse data
    return if msg.from is @name
    return if msg.to and msg.to isnt @name
    @emit '*', msg
    if msg.type
      @emit msg.type, msg

module.exports = Node

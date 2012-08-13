EventEmitter = require('events').EventEmitter

zmq = require 'zmq'

class Node extends EventEmitter
  @connect = (args...) -> Node().connect args...
  @listen = (args...) -> Node().listen args...
  
  constructor: (name) ->
    return new Node(name) if this is global

    @name = name or Math.random().toFixed(10).slice(2)

    @pub = zmq.socket 'pub'
    @sub = zmq.socket 'sub'
    @sub.subscribe ''
    @sub.on 'message', @recv

  connect: (host, subport=44445, pubport=44446) -> 
    @pub.connect "tcp://#{host}:#{subport}"
    @sub.connect "tcp://#{host}:#{pubport}"
    this
  
  listen: (host="127.0.0.1", subport=44445, pubport=44446) ->
    @pub.bindSync "tcp://#{host}:#{pubport}"
    @sub.bindSync "tcp://#{host}:#{subport}"
    this
   
  sendRaw: (msg) ->
    @pub.send JSON.stringify msg

  forward: (msg) => @sendRaw msg

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

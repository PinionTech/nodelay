Node = require './lib/node'

EventEmitter = require('events').EventEmitter
{fork} = require 'child_process'
path = require 'path'
fs = require 'fs'

forkCoffee = (script, options={}) ->
  coffeePath = path.join __dirname, 'node_modules/.bin/coffee'
  [oldExecPath, process.execPath] = [process.execPath, coffeePath]
  if not fs.existsSync script
    script = path.join __dirname, script
    options.cwd ?= __dirname

  child = fork script, [], options
  
  process.execPath = oldExecPath
  child

class Nodelay extends EventEmitter
  constructor: (name, init) ->
    return new Nodelay name, init if this is global

    @name = name

    @resources = {}
    @controllers = []
    @workers = []
    @monitors = []

    @proxy = {in: [], out:[]}
    @node = new Node name

    dsl =
      instance: this
      node: @node
      upstream: (host, port) => @upstream = {host, port}
      bind: (@bind) =>
      proxy: (proxy) =>
        @proxy.in.push proxy.in... if proxy.in
        @proxy.out.push proxy.out... if proxy.out
      on: @on
      workers: (@workers...) =>
      monitors: (@monitors...) =>
      controllers: (@controllers...) =>
      privkey: (privkey) =>
        @privkey = fs.readFileSync(privkey)
        @node.privkey = @privkey
      pubkey: (pubkey) =>
        @pubkey = fs.readFileSync(pubkey)
        @node.pubkey = @pubkey
        @node.auth = (msg) -> console.log "got auth msg", msg; true
      resource: (name, resource) =>
        resource.name = name
        @resources[name] = resource

    init?.call dsl

    if @upstream
      @node.connect @upstream.host, @upstream.port, =>
        @emit "connected"
        if @privkey
          @node.send type: 'auth', signed: true  
    #console.log "upstream is", @host, @pubport, @subport

    console.log @node.parent

    @node.listen @bind or '127.0.0.1'
    @node.parent.on '*', (msg) => @node.children.forward
    @node.children.on '*', @node.children.forward
    @node.children.on '*', (msg) => @node.parent.forward msg if @proxy.out and msg.type in @proxy.out

    @node.children.on 'metric', (msg) =>
      msg = JSON.parse(JSON.stringify(msg))
      msg.data.resource = msg.data.resource + "@" + @name
      if typeof msg.from is "object"
        msg.unshift @name
      else
        msg.from = [@name, msg.from]
      @node.parent.forward msg

#    @node.on '*', (msg) => @node.forward (msg) i:f !@proxy or msg.type in @proxy
 
    forkCoffee "controllers/#{controller}.coffee" for controller in @controllers
    forkCoffee "workers/#{worker}.coffee" for worker in @workers
    forkCoffee "monitors/#{monitor}.coffee" for monitor in @monitors

    setTimeout =>
      #console.log "resources:", @resources
      @node.send "add resource", resource for name, resource of @resources
    , 2000


Nodelay.Node = Node
module.exports = Nodelay 

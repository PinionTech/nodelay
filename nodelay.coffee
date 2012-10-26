Node = require './lib/node'

EventEmitter = require('events').EventEmitter
{fork} = require 'child_process'
path = require 'path'
fs = require 'fs'

forkCoffee = (script, args, options={}) ->
  # XXX This doesn't seem to be needed anymore - somehow it's auto-finding the coffee binary
  #coffeePath = path.join __dirname, 'node_modules/.bin/coffee'
  #[oldExecPath, process.execPath] = [process.execPath, coffeePath]
  if not fs.existsSync script
    script = path.join __dirname, script
    options.cwd ?= __dirname

  child = fork script, args, options
  child.on 'exit', (code, signal) -> handleRestart code, signal, script, args, options
  
  #process.execPath = oldExecPath
  child


handleRestart = (code, signal, script, args, options) ->
  onedirname = path.join path.basename(path.dirname(script)), path.basename(script)
  console.log onedirname, "exited with", if code then "code #{code}" else "signal #{signal}"
  setTimeout ->
    
    console.log "restarting #{onedirname}"
    forkCoffee script, args, options
  ,5000

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
      bind: (@bind, @port) =>
      proxy: (proxy) =>
        @proxy.in.push proxy.in... if proxy.in
        @proxy.out.push proxy.out... if proxy.out
      on: @on
      scope: (@scope...) =>
      workers: (@workers...) =>
      monitors: (@monitors...) =>
      controllers: (@controllers...) =>
      privkey: (privkey) =>
        @privkey = fs.readFileSync(privkey)
        @node.privkey = @privkey
      pubkey: (pubkey) =>
        @pubkey = fs.readFileSync(pubkey)
        @node.pubkey = @pubkey
        @node.auth = (msg) -> true
      resource: (name, resource) =>
        resource.name = name
        @resources[name] = resource

    init?.call dsl

    if @upstream
      @node.connect @upstream.host, @upstream.port, =>
        @emit "connected"

    @node.listen @bind, @port
    

    if @scope
      @node.parent?.inFilter = (msg) =>
        if typeof msg?.resource is 'object' and msg.resource instanceof Array
          for scope in @scope
            break unless msg.resource[0] == scope
            msg.resource.shift()
        msg

      @node.parent?.outFilter = (msg) =>
        #console.log @node.name, "outfiltering with", @scope
        if msg.resource or (msg.type is "listen" and msg.data.resource)
          msg = JSON.parse JSON.stringify msg
        if msg.resource
          msg.resource = [msg.resource] if typeof msg.resource is 'string'
          msg.resource.unshift @scope...
        if msg.type is "listen" and msg.data.resource
          msg.data.resource = [msg.resource] if typeof msg.resource is 'string'
          msg.data.resource.unshift @scope...
        msg
      
    @node.parent?.on {type: '*', resource: []}, (msg) => @node.children.forward msg unless msg.scope is 'link'

    # This is probably a bad idea - we should only listen for all resource updates from children
    # Parent resource updates might be out of scope
    @node.resources.watch()

    #@node.children.on 'resource update', @node.resources.handleResourceUpdate
    
    @node.children.on '*', (msg) => @node.children.forward msg unless msg.scope is 'link'
    #@node.children.on 'listen', (msg) =>

    @node.children.on '*', (msg) =>
      return if msg.scope is 'link'
      msg = JSON.parse JSON.stringify msg
      if typeof msg.from is "object"
        msg.from.unshift @name
      else if typeof msg.from is "undefined"
        msg.from = @name
      else
        msg.from = [@name, msg.from]

      @node.parent?.forward msg

    args = if @port then [@port] else []
    forkCoffee "controllers/#{controller}.coffee", args for controller in @controllers
    forkCoffee "workers/#{worker}.coffee", args for worker in @workers
    forkCoffee "monitors/#{monitor}.coffee", args for monitor in @monitors

    for name, resource of @resources
      res = @node.resource name
      res.update resource
      #res.watch()

      #@node.children?.send type: "add resource", resource: name, data: resource
      #@node.parent?.send type: "add resource", resource: [@name, name], data: resource


Nodelay.Node = Node
module.exports = Nodelay 

EventEmitter = require('events').EventEmitter
uidNumber = require 'uid-number'
coffee = require 'coffee-script'
{fork} = require 'child_process'
path = require 'path'
fs = require 'fs'

Node = require './lib/node'
nodelay_monitor = require './lib/nodelay_monitor'

children = []



forkCoffee = (script, args, options={}) ->
  go = ->
    #console.log "got forkCoffee", script, args, options
    coffeePath = path.join __dirname, 'node_modules/.bin/coffee'
    [oldExecPath, process.execPath] = [process.execPath, coffeePath]
    if not fs.existsSync script
      script = path.join __dirname, script
      options.cwd ?= __dirname

    child = fork script, args, options
    child.on 'exit', (code, signal) -> handleRestart code, signal, script, args, options
    children.push child
    process.execPath = oldExecPath
    child

  if options.user
    uidNumber options.user, (err, uid) ->
      if err
        console.warn "uid fetch failed for user", options.user
      else
        options.uid = uid
      go()
  else
    go()

process.on 'uncaughtException', (e) ->
  child.kill() for child in children
  console.warn "Master process dying due to exception"
  console.warn e.stack
  process.nextTick ->
    process.exit()


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

    @resources = []
    @controllers = {}
    @workers = {}
    @monitors = {}

    @proxy = {in: [], out:[]}
    @node = new Node name

    processNodes = (type) => (nodes..., opts) =>
      if typeof opts isnt 'object'
        nodes.push opts
        opts = {}

      #console.log "processing node", node for node in nodes
      for node in nodes
        _opts = {}
        _opts[k] = v for k, v of opts
        this[type][node] = _opts

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
      workers: processNodes 'workers'
      monitors: processNodes 'monitors'
      controllers: processNodes 'controllers'
      privkey: (privkey) =>
        @privkey = fs.readFileSync(privkey)
        @node.privkey = @privkey
      pubkey: (pubkey) =>
        @pubkey = fs.readFileSync(pubkey)
        @node.pubkey = @pubkey
        @node.auth = (msg) -> true
      resource: (name, resource) =>
        @resources.push {name, resource}
      include: (file) =>
        if fs.statSync(file).isDirectory()
          dsl.include path.join(file, _file) for _file in fs.readdirSync file when _file.match /\.coffee$/
        else
          nodelay = Nodelay
          code = fs.readFileSync file, 'utf8'
          fn = eval "(function(){" + coffee.compile(code, bare: true) + "})"
          fn.call dsl

    init?.call dsl

    @port ||= 44445

    if @upstream
      @node.connect @upstream.host, @upstream.port, =>
        @emit "connected"

    @node.listen @bind, @port


    if @scope
      @node.parent?.inFilter = (msg) =>
        if typeof msg?.resource is 'object' and Array.isArray(msg.resource)
          for scope in @scope
            break unless msg.resource[0] == scope
            msg.resource.shift()
        msg

      @node.parent?.outFilter = (msg) =>
        #console.log @node.name, "outfiltering with", @scope
        if msg.resource or (msg.type is "listen" and Array.isArray msg.data.resource)
          newmsg = {}
          newmsg[k] = v for k, v of msg
          msg = newmsg
        if msg.resource
          if typeof msg.resource is 'string'
            msg.resource = [msg.resource]
          else
            msg.resource = msg.resource.slice()
          msg.resource.unshift @scope...
        if msg.type is "listen" and Array.isArray(msg.data.resource)
          newdata = {}
          newdata[k] = v for k, v of msg.data
          msg.data = newdata

          if typeof msg.data.resource is 'string'
            msg.data.resource = [msg.data.resource]
          else
            msg.data.resource = msg.data.resource.slice()
          msg.data.resource.unshift @scope...
        msg

    # Forward mesages from parent to children
    @node.parent?.on {type: '*', resource: []}, (msg) => @node.children.forward msg unless msg.scope is 'link'

    # This is probably a bad idea - we should only listen for all resource updates from children
    # Parent resource updates might be out of scope
    @node.resources.watch()

    #@node.children.on 'resource update', @node.resources.handleResourceUpdate


    # Forward messages from one child to all children
    @node.children.on '*', (msg) => @node.children.forward msg unless msg.scope is 'link'
    #@node.children.on 'listen', (msg) =>

    # Forward messages from children to parent
    @node.children.on '*', (msg) =>
      return if msg.scope is 'link' or !@node.parent
      newmsg = {}
      newmsg[k] = v for k, v of msg

      if typeof newmsg.from is "object"
        newmsg.from.unshift @name
      else if typeof msg.from is "undefined"
        newmsg.from = @name
      else
        newmsg.from = [@name, newmsg.from]

      @node.parent.forward newmsg

    args = [@port]

    forkCoffee "controllers/#{controller}.coffee", args, options for controller, options of @controllers
    forkCoffee "workers/#{worker}.coffee", args, options for worker, options of @workers
    forkCoffee "monitors/#{monitor}.coffee", args, options for monitor, options of @monitors

    nodelay_monitor this

    for {name, resource} in @resources
      res = @node.resources.sub name
      res.update resource
      #res.watch()

      #@node.children?.send type: "add resource", resource: name, data: resource
      #@node.parent?.send type: "add resource", resource: [@name, name], data: resource


Nodelay.Node = Node
module.exports = Nodelay

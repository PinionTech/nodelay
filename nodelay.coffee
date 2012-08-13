Node = require './lib/node'
{fork} = require 'child_process'

forkCoffee = (path, options={}) ->
  [oldExecPath, process.execPath] = [process.execPath,'node_modules/.bin/coffee']
  console.log "fork", path
  child = fork path, [], options
  process.execPath = oldExecPath
  child

class Nodelay
  constructor: (name, init) ->
    return new Nodelay name, init if this is global

    @resources = {}
    @controllers = []
    @workers = []
    @monitors = []

    @node = new Node name

    dsl =
      instance: this
      upstream: (@host, @pubport, @subport) =>
      proxy: (@proxy) =>
      workers: (@workers...) =>
      monitors: (@monitors...) =>
      controllers: (@controllers...) =>
      resource: (name, resource) =>
        resource.name = name
        @resources[name] = resource

    init?.call dsl

    console.log "upstream is", @host, @pubport, @subport

    @node.listen '127.0.0.1'
    @node.on '*', @node.forward
 
    forkCoffee "controllers/#{controller}.coffee" for controller in @controllers
    forkCoffee "workers/#{worker}.coffee" for worker in @workers
    forkCoffee "monitors/#{monitor}.coffee" for monitor in @monitors

    setTimeout =>
      console.log "resources:", @resources
      @node.send "add resource", resource for name, resource of @resources
    , 1000

module.exports = Nodelay 

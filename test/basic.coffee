vows    = require 'vows'
assert  = require 'assert'
service = require '../service'

describe = (name, bat) -> vows.describe(name).addBatch(bat).export(module)

# Make coffeescript not return anything
# This is needed because vows topics do different things if you have a return value
t = (fn) ->
  (args...) ->
    fn.apply this, args
    return

describe "A service"
  "is created with service(name, args)":
    topic: ->
      service "service"
        start: "daemons/simple.coffee"
        stop: (s) -> "kill #{s}"
    
    "which returns an object": (s) -> assert.isObject s
    
    "and has a method start()":
      topic: t (s) -> s.start(@callback)
      
      "which starts the service": (blah) -> assert.notEqual p.pid, undefined

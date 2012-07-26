fs      = require 'fs'
path    = require 'path'
{exec}  = require 'child_process'

vows    = require 'vows'
assert  = require 'assert'

service = require '../service'

describe = (name, bat) -> vows.describe(name).addBatch(bat).export(module)
exists = fs.existsSync or path.existsSync


# Make coffeescript not return anything
# This is needed because vows topics do different things if you have a return value
t = (fn) ->
  (args...) ->
    fn.apply this, args
    return

describe "A fully managed service"
  "is created with service(name, args)":
    topic: ->
      service "service"
        start: "daemons/simple.coffee"
        pidFile: "/tmp/service#{(''+Math.random().toFixed(10)).slice(2)}"
    
    "which returns an object": (s) -> assert.isObject s
    
    "and started with start()":
      topic: (s) -> s.start()
      
      "which gives the service a pid": (s) ->
        assert.notEqual s.pid, undefined

      "which runs the service": (s) ->
        assert.ok exists "/proc/#{s.pid}"

      "and writes a pidfile": (s) ->
        pid = fs.readFileSync s.pidFile
        assert.equal pid, s.pid

      "and stopped with stop()":
        topic: (s) -> s.stop()

        "which stops the service": (s) ->
          assert.ok !exists "/proc/#{s.pid}"

        "and stops all subprocesses":
          topic: (_, s) ->
            exec "ps -o '%p' --no-headers --ppid #{s.pid}", @callback
            null
  
          "": (err, stdout, stderr) ->          
            assert.equal stdout, null


        "and deletes the pidfile": (s) ->
          assert.ok !exists s.pidFile 

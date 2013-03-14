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
        start: "coffee daemons/simple.coffee"
        pidFile: "/tmp/service#{(''+Math.random().toFixed(10)).slice(2)}"

    "which returns an object": (s) -> assert.isObject s

    "and started with start()":
      topic: t (s) -> s.start (e) => @callback e, s

      "which gives the service a pid": (s) ->
        assert.notEqual s.pid, undefined

      "which runs the service": (e, s) ->
        assert.ok exists "/proc/#{s.pid}"

      "which writes a pidfile": (e, s) ->
        pid = fs.readFileSync s.pidFile
        assert.equal pid, s.pid

      "and stopped with stop()":
        topic: t (s) -> s.stop (e) =>
          @callback e, s

        "which stops the service": (s) ->
          assert.ok !exists "/proc/#{s.pid}"

        "which stops all subprocesses":
          topic: t (_, s) ->
            exec "ps -o '%p' --no-headers --ppid #{s.pid}", @callback

          "": (err, stdout, stderr, a, b, c) ->
            assert.equal stdout, ''


        "and deletes the pidfile": (s) ->
          assert.ok !exists s.pidFile


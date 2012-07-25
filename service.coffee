{exec} = require 'child_process'

class Service
  constructor: (@name, @opts) ->

  start: (cb) ->
    @process = @run @opts.start, cb
    @pid = @process.pid
  
  stop: (cb) -> @run @opts.stop, cb
  
  kill: (args...) -> @process.kill args...
  
  run: (cmd, cb) ->
    if typeof cmd is 'function'
      cmd = cmd(this)
    if typeof cmd is 'object'
      cmd
    else
      exec cmd




module.exports = (args...) -> new Service(args...)
fs            = require 'fs'
{exec, spawn} = require 'child_process'

run = (cmd, extra_opts) ->
  opts = 
    detached: true
  opts[k] = v for k, v of extra_opts

  spawn "sh", ["-c", cmd], opts


class Service
  constructor: (@name, @opts) ->
    for k in "pidFile".split ' '
      @[k] = @opts[k] if @opts[k]?


  start: ->
    @process = @run @opts.start
    @pid = @process.pid
    if @pidFile
      fs.writeFileSync @pidFile, @pid, 'utf8'
    @
  
  stop: ->
    if @opts.stop
      @run @opts.stop
    else
      run "kill #{s}"
    
    if @pidFile
      fs.unlinkSync @pidFile
      console.log "unlinked", @pidFile

    @
  
  readStatus: ->

  kill: (args...) -> @process.kill args...
  
  run: (cmd) ->
    if typeof cmd is 'function'
      cmd = cmd(this)
    if typeof cmd is 'object'
      cmd
    else
      #console.log "Execing", cmd
      run cmd




module.exports = (args...) -> new Service(args...)
fs            = require 'fs'
{exec, spawn} = require 'child_process'

run = (cmd, extra_opts, cb) ->
  [extra_opts, cb] = [undefined, extra_opts] if typeof extra_opts is 'function'
  
  opts = 
    detached: true
    stdio: 'inherit'
  opts[k] = v for k, v of extra_opts

  proc = spawn "sh", ["-c", cmd], opts

  proc.on 'exit', ->
    cb?()


class Service
  Service.allServices = []

  constructor: (name, opts={}) ->
    return (new Service name, opts) if this is global
    [@name, @opts] = [name, opts]

    Service.allServices.push this
    for k in "pidFile".split ' '
      @[k] = @opts[k] if @opts[k]?


  start: (cb) ->
    @process = @run @opts.start
    
    #TODO: Call callback only when process is actually running
    done = =>
      @pid = @process.pid+1 #This is way dodgy
      if @pidFile
        fs.writeFileSync @pidFile, @pid, 'utf8'
      cb?()

    done()
  
  stop: (cb) ->
    done = =>
      if @pidFile
        fs.unlinkSync @pidFile
      cb?()

    if @opts.stop
      @run @opts.stop, done
    else
      @run "kill -- -#{@pid}", done

    
  
  readStatus: ->

  kill: (args...) -> @process.kill args...
  
  run: (cmd, cb) ->
    if typeof cmd is 'function'
      cmd = cmd this, cb
    
    if typeof cmd is 'object'
      cb cmd
    else
      run cmd, cb




module.exports = Service
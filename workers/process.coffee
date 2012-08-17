fs            = require 'fs'
path          = require 'path'
{exec, spawn} = require 'child_process'

Node  = require '../lib/node'

run = (cmd, extra_opts, cb) ->
  [extra_opts, cb] = [undefined, extra_opts] if typeof extra_opts is 'function'
  
  opts = 
    detached: true
    stdio: 'inherit'
  opts[k] = v for k, v of extra_opts

  proc = spawn "sh", ["-c", cmd], opts

  proc.on 'exit', ->
    cb?()

services = {}

node = Node('process worker').connect 'localhost'

node.on 'add resource', ({data: service}) ->
  #console.log "adding service", service 
  services[service.name] = service 

node.on 'remove resource', ({data: service}) ->
  delete services[service.name]

node.on 'start', ({data: name}) ->
  if service = services[name]
    opts = {}
    opts[k] = v for k, v of service when k in "cwd".split(" ")
    process = run service.start, opts

    #TODO: Call callback only when process is actually running
    done = =>
      pid = process.pid+1 #This is way dodgy
      if service.pidFile && service.writePidFile
        fs.writeFileSync service.pidFile, pid, 'utf8'

    done()

node.on 'stop', ({data: name}) ->
  if service = services[name]

    if service.stop
      run service.stop
    else
      run "kill -- -`cat #{service.pidFile} | xargs ps --no-header -o pgrp -p`"

    #if service.pidFile && fs.existsSync service.pidFile
    #  fs.unlinkSync service.pidFile


node.on 'kill', ({data: pid}) ->
 run "kill -9 #{pid}"


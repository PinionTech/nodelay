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

node = Node('process worker').connect 'localhost', process.argv[2]

services = node.resource({start: '*'})

services.on 'start', (res) ->
  start res

start = (res, cb) ->
  service = res.data
  #console.log "starting", service
  opts = {}
  opts[k] = v for k, v of service when k in "cwd".split(" ")
  process = run service.start, opts

  #TODO: Call callback only when process is actually running
  done = ->
    pid = process.pid+1 #This is way dodgy
    if service.pidFile && service.writePidFile
      fs.writeFileSync service.pidFile, pid, 'utf8'
    cb?()

  # Don't use the process callback 'cause we don't know if the process terminates
  done()

stop = (res, cb) ->
  service = res.data
  #console.log "stopping", service
  if service.stop
    run service.stop, cb
  else
    run "kill -- -`cat #{service.pidFile} | xargs ps --no-header -o pgrp:1 -p`", cb
  #if service.pidFile && fs.existsSync service.pidFile
  #  fs.unlinkSync service.pidFile

services.on 'stop', (res) -> stop res

services.on 'restart', (res) ->
  stop res, ->
    setTimeout ->
      start res
    1000


# This should probably go somewhere else
node.on 'kill', ({resource}) ->
  #console.log "trying to kill", resource
  run "kill -9 #{resource[resource.length-1]}"




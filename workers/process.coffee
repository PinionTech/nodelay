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

node.on 'add resource', ({data: service}) ->
  #console.log "adding service", service 
  services[service.name] = service 

node.on 'remove resource', ({data: service}) ->
  delete services[service.name]

start = (service, cb) ->
  console.log "starting", service
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

node.on 'start', ({data: name}) ->
  if service = services[name]
    start service


stop = (service, cb) ->
  console.log "stopping", service
  if service.stop
    run service.stop, cb
  else
    run "kill -- -`cat #{service.pidFile} | xargs ps --no-header -o pgrp -p`", cb

node.on 'stop', ({data: name}) ->
  if service = services[name]
    stop service

    #if service.pidFile && fs.existsSync service.pidFile
    #  fs.unlinkSync service.pidFile


node.on 'restart', ({data: name}) ->
  if service = services[name]
    stop service, ->
      setTimeout ->
        start service
      1000

# This should probably go somewhere else
node.on 'kill', ({data: pid}) ->
 run "kill -9 #{pid}"




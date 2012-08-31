util = require 'util'
path = require 'path'

{exec, spawn} = require 'child_process'
Node  = require '../lib/node'

node = Node('steam updates monitor').connect 'localhost', process.argv[2]

watchers = {}

watch = (file, cb) ->
  child = spawn 'tail', ['-n','0','-F', file]
  child.stdout.on 'data', (data) ->
    cb data.toString('utf8')
  child.on 'exit', ->
    setTimeout ->
      watch file, cb
    ,500
  child

node.on 'add resource', ({resource: name, data: res}) ->
  return unless typeof name is 'string'
  if res.steamDir
    watchFile = path.join res.steamDir, "logs", "content_log.txt"

    watchers[name] ||= watch watchFile, (data) ->
      for line in data.split '\n'
        #node.send "got data", data.trim()
        if match = line.match /\[(.*?)\] (.*)/
          time = new Date(match[1])
          msg = match[2]

          if match = msg.match /AppID (\d+) state changed : (.*?) = (.*)/
            [_, appid, stateCode, states] = match
            node.send type: "metric", resource: name, data: steam: {appid, stateCode, states:states.split(',')}, time: time.toISOString()
          
          if match = msg.match /Scheduler update appID (\d+)/
            node.send type: "steam update", resource: name, data: time: time.toISOString()

          if match = msg.match /Scheduler finished appID (\d+)/
            node.send type: "steam update finished", resource: name, data: time: time.toISOString()


node.on 'remove resource', ({resource: name}) ->
  return unless typeof name is 'string'
  delete watchers[name]


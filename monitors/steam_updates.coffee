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


# TODO: logic for matching which update goes with which server instance

node.resource steam: '*', (res) ->
  steam = res.sub('steam')
  watchFile = path.join steam.data.steamDir, "logs", "content_log.txt"

  watchers[res.data.name] ||= watch watchFile, (data) ->
    for line in data.split '\n'
      #node.send "got data", data.trim()
      if match = line.match /\[(.*?)\] (.*)/
        msg = match[2]

        if match = msg.match /AppID (\d+) state changed : (.*?) = (.*)/
          [_, appid, stateCode, states] = match
          update = {}
          update[appid] = {stateCode, states:states.split(',')}
          steam.update update

        if match = msg.match /Scheduler update appID (\d+)/
          res.send "steam update"

        if match = msg.match /Scheduler finished appID (\d+)/
          res.send "steam update finished"

Node = require '../lib/node'

node = Node('steam update killer').connect 'localhost', process.argv[2]

node.resource(steam: '*').on 'steam update finished', (res) ->
  for port of res.data.srcds when !isNaN parseInt port
    res.at('srcds',port)?.send "rcon", "sv_shutdown"

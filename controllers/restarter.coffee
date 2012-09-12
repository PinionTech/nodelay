Node = require '../lib/node'

node = Node('restarter').connect 'localhost', process.argv[2]

debounce = {}

node.resource restart: true, (res) ->
  resPath = res.path.join('\x1f')
  if !res.data.running and res.data.process and !debounce[resPath]
    res.send 'start'
    debounce[resPath] = true
    setTimeout ->
      delete debounce[resPath]
    , 30 * 1000

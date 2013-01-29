http = require 'http'
url = require 'url'

Node  = require '../lib/node'

CHECK_INTERVAL = 5000

node = Node('process monitor').connect 'localhost', process.argv[2]

selector = node.resource url: '*'

setInterval ->
  selector.each (path, res) ->
    data = res.data    
    
    d = new Date()
    wasUp = data.up
    opts = url.parse data.url
    opts.agent = false
    up = (data) ->
      data.latency ?= new Date() - d
      data.up = true
      res.update data
      res.send "up" if !wasUp 
    down = (data) ->
      data.latency ?= new Date() - d
      data.up = false
      res.update data
      res.send "down" if wasUp

    req = http.get opts, (resp) ->
      if resp.statusCode < 400
        up {
          statusCode: resp.statusCode
        }
      else
        down {
          statusCode: resp.statusCode
        }
    req.on 'error', (err) ->
      down { statusCode: null, latency: null }
      res.send "http error", err.message      

, CHECK_INTERVAL



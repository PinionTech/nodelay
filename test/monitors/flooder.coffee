util = require 'util'
fs   = require 'fs'
proc = require 'proc'
Node  = require '../../lib/node'

node = Node('flooder').connect 'localhost', process.argv[2]

selector = node.resource flood: true

setInterval ->
  selector.each (path, res) ->
    sub = res.sub "sub"+Math.floor(Math.random()*10)
    sub.update {a:Math.random(), b:Math.random(), c:Math.random()}#, 'clobber'
#, 5000

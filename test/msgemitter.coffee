fs      = require 'fs'
path    = require 'path'
{exec}  = require 'child_process'

vows    = require 'vows'
assert  = require 'assert'

node = require '../lib/node'

MsgEmitter = node.MsgEmitter

describe = (name, bat) -> vows.describe(name).addBatch(bat).export(module)
exists = fs.existsSync or path.existsSync


# Make coffeescript not return anything
# This is needed because vows topics do different things if you have a return value
t = (fn) ->
  (args...) ->
    fn.apply this, args
    return

describe "A msg emitter"
  "is created with new MsgEmitter()":
    topic: -> new MsgEmitter
    
    "which returns an object": (s) -> assert.isObject s

  "when listening for anything": 
    topic: ->
      m = new MsgEmitter()
      m.on {}, (msg) => m.calledCount++
      m.calledCount = 0
      m

    "and a message is emitted":
      topic: (m) ->
        m.emit {asdf: 1234}
        m
      "the callback fires once": (m) ->
        assert.equal m.calledCount, 1

  "when listening for a string": 
    topic: ->
      m = new MsgEmitter()
      m.on "hello", (msg) => m.calledCount[msg.key] ||= 0; m.calledCount[msg.key]++
      m.calledCount = {}
      m

    "and a message with a type set to that string is emitted":
      topic: (m) ->
        m.emit {type: "hello", key: 1}
        m
      "the callback fires once": (m) ->
        assert.equal m.calledCount[1], 1

    "and a message with a different type is emitted":
      topic: (m) ->
        m.emit {type: "world", key: 2}
        m
      "the callback does not fire": (m) ->
        assert.equal m.calledCount[2], undefined


  "when listening for two different strings": 
    topic: ->
      m = new MsgEmitter()
      m.on "hello", (msg) => m.calledCount[msg.key] ||= 0; m.calledCount[msg.key]++
      m.on "world", (msg) => m.calledCount[msg.key] ||= 0; m.calledCount[msg.key]++
      m.calledCount = {}
      m

    "and a message with the first type is called":
      topic: (m) ->
        m.emit {type: "hello", key: 1}
        m
      "the callback fires once": (m) ->
        assert.equal m.calledCount[1], 1

    "and a message with the second type is called":
      topic: (m) ->
        m.emit {type: "world", key: 2}
        m
      "the callback fires once": (m) ->
        assert.equal m.calledCount[2], 1

    "and a message with a different type is emitted":
      topic: (m) ->
        m.emit {type: "troz", key: 3}
        m
      "the callback does not fire": (m) ->
        assert.equal m.calledCount[3], undefined





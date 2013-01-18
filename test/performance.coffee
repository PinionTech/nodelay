fs      = require 'fs'
path    = require 'path'
{exec}  = require 'child_process'

vows    = require 'vows'
assert  = require 'assert'

node    = require '../lib/node'

memwatch = require 'memwatch'

memwatch.on 'leak', (info) ->
  console.log "Memory leak: ", info

#setInterval ->
#  console.log "forcing GC"
#  memwatch.gc()
#, 1000

#describe = (name, bat) -> vows.describe(name).addBatch(bat).export(module)

# Make coffeescript not return anything
# This is needed because vows topics do different things if you have a return value
t = (fn) ->
  (args...) ->
    fn.apply this, args
    return


time = ({listeners, msgtypes, resources, messages}, cb) ->
  em = new node.MsgEmitter
  count = 0

  done = ->
    cb {listeners, msgtypes, messages, resources}, new Date() - d

  for [1..listeners]
    for msgtype in [1..msgtypes]
      em.on "type#{msgtype}", ->
        count++
        done() if count == listeners * messages

  d = new Date()
  for [1..messages/resources/msgtypes]
    for res in [1..resources]
      msg = {resource: ["res#{res}","sub#{res+1}","subsub#{res+2}"]}
      for msgtype in [1..msgtypes]
        msg.type = "type#{msgtype}"
        em.emit msg
  null


tests = [
  # {listeners: 10, msgtypes: 10, resources: 1, messages: 500000}
  # {listeners: 10, msgtypes: 20, resources: 1, messages: 500000}
  # {listeners: 10, msgtypes: 30, resources: 1, messages: 500000}
  # {listeners: 10, msgtypes: 40, resources: 1, messages: 500000}
  
  {listeners: 100, msgtypes: 1, resources: 1, messages: 100000}
  {listeners: 100, msgtypes: 10, resources: 1, messages: 100000}
  {listeners: 100, msgtypes: 100, resources: 1, messages: 100000}
  
  {listeners: 100, msgtypes: 1, resources: 10, messages: 100000}
  {listeners: 100, msgtypes: 1, resources: 100, messages: 100000}

  {listeners: 100, msgtypes: 10, resources: 10, messages: 100000}
  {listeners: 100, msgtypes: 100, resources: 100, messages: 100000}
]

runTests = (cb, i = 0) ->
  d = tests[i]
  console.log "#{d.listeners} listeners, #{d.msgtypes} types, #{d.resources} resources, #{d.messages} messages"
  time tests[i], (d, t) ->
    console.log "\t#{t}ms (#{(d.messages/t).toFixed(2)} msg/s)"
    if i + 1 < tests.length
      process.nextTick ->
        runTests cb, i + 1
    else
      cb?()

console.log "Press Ctrl-D to start"
fs.readFile '/dev/stdin', ->
  runTests ->
    console.log "done"

# describe "MsgEmitter"
#   "on two values":
#     "when the values are unequal":
#       topic: -> onlyChanges 1, 2
      
#       "returns the second value": (v) -> assert.equal v, 2

#     "when the values are equal":
#       topic: -> onlyChanges 5, 5
      
#       "returns null": (v) -> assert.strictEqual v, null

#   "on two arrays":
#     "when the second is longer than the first":
#       topic: -> onlyChanges [1,2,3,4], [1,2,3,4,5,6]
    
#       "returns the second value": (v) -> assert.deepEqual v, [1,2,3,4,5,6]

#     "when the second is shorter than the first":
#       topic: -> onlyChanges [1,2,3,4], [1,2]
    
#       "returns the second value": (v) -> assert.deepEqual v, [1,2]

#     "when the second is equal to the first":
#       topic: -> onlyChanges [1,2,3,4], [1,2,3,4]
    
#       "returns null": (v) -> assert.strictEqual v, null

#   "on two objects":
#     "when there are new keys in the new object":
#       topic: -> onlyChanges {a:1}, {a:1, b:2}

#       "returns just the new keys": (v) -> assert.deepEqual v, {b:2}

#     "when there are the same keys with changed values":
#       topic: -> onlyChanges {a:1, b:2}, {a:1, b:3}
    
#       "returns the keys with changed values": (v) -> assert.deepEqual v, {b:3}

#     "when there are the same keys with the same values":
#       topic: -> onlyChanges {a:1, b:2}, {a:1, b:2}
    
#       "returns null": (v) -> assert.strictEqual v, null

#     "when keys are removed in the new object":
#       topic: -> onlyChanges {a:1, b:2}, {a:1}
    
#       "returns null": (v) -> assert.strictEqual v, null

#   "on an object containing objects":
#     "when the nested objects have changes":
#       topic: -> onlyChanges {a:{a:1,b:2}, b:{a:1,b:2}}, {a:{a:1,b:2}, b:{a:1,b:1}}

#       "returns only the changed objects": (v) -> assert.deepEqual v, {b:{b:1}}

#     "when the nested objects have no changes":
#       topic: -> onlyChanges {a:{a:1,b:2}, b:{a:1,b:2}}, {a:{a:1,b:2}, b:{a:1,b:2}}

#       "returns null": (v) -> assert.strictEqual v, null

#   "on same-sized arrays containing objects":
#     "when the nested objects have changes":
#       topic: -> onlyChanges [{a:1},{b:2},{c:3}],[{a:1},{b:1},{c:3}]

#       "returns only the changed objects, and fills the rest of the array with empty objects": (v) -> assert.deepEqual v, [{},{b:1},{}]

#     "when the nested objects have no changes":
#       topic: -> onlyChanges [{a:1},{b:2},{c:3}],[{a:1},{b:2},{c:3}]

#       "returns null": (v) -> assert.strictEqual v, null

#   "on same-sized arrays containing arrays":
#     "when the nested arrays have changes":
#       topic: -> onlyChanges [[1,2,3],[4,5,6],[7,8,9]],[[1,1,3],[4,5,6],[7,8,9]]

#       "returns all elements of the array": (v) -> assert.deepEqual v, [[1,1,3],[4,5,6],[7,8,9]]

#     "when the nested arrays have no changes":
#       topic: -> onlyChanges [[1,2,3],[4,5,6],[7,8,9]],[[1,2,3],[4,5,6],[7,8,9]]

#       "returns null": (v) -> assert.strictEqual v, null



fs      = require 'fs'
path    = require 'path'
{exec}  = require 'child_process'

vows    = require 'vows'
assert  = require 'assert'

resource = require '../lib/resource'

describe = (name, bat) -> vows.describe(name).addBatch(bat).export(module)
exists = fs.existsSync or path.existsSync

Vclock = resource.Vclock

# Make coffeescript not return anything
# This is needed because vows topics do different things if you have a return value
t = (fn) ->
  (args...) ->
    fn.apply this, args
    return

{onlyChanges, snapshotMatch} = resource

describe "A vclock"
  "is created with vclock(node)":
    topic: -> new Vclock {name: "name"}

    "which returns an object": (s) -> assert.isObject s

describe "A vclock"
  "When incremented":
    topic: ->
      v = new Vclock {name: "name"}
      v.inc ['a']
      v

    "increments the vector of our node": (v) ->
      assert.equal v.vclocks.a.name, 1

  "When updated":
    topic: ->
      v = new Vclock {name: "name"}
      v.inc ['a']
      v.update ['a'], dave: 1, bill: 2, jim: 1
      v.update ['a'], bill: 1
      v.update ['a'], jim: 2
      v

    "for new nodes, just inserts their version": (v) ->
      assert.equal v.vclocks.a.dave, 1

    "for old nodes, picks the new version if it's higher": (v) ->
      assert.equal v.vclocks.a.jim, 2

    "for old nodes, ignores the new version if it's lower": (v) ->
      assert.equal v.vclocks.a.bill, 2

    "and otherwise doesn't change any versions": (v) ->
      assert.equal v.vclocks.a.name, 1


  "When a node is removed":
    topic: ->
      v = new Vclock {name: "name"}
      v.inc ['a']
      v.update ['a'], dave: 1
      v.update ['b'], dave: 1
      v.remove 'dave'
      v

    "Its versions are removed from every vector": (v) ->
      assert.equal v.vclocks.a.dave, undefined
      assert.equal v.vclocks.b.dave, undefined

    "But other nodes are left intact": (v) ->
      assert.equal v.vclocks.a.name, 1

  "An update conflicts":
    topic: ->
      v = new Vclock {name: "name"}
      v.update ['a'], sam: 1, dave: 2, bill: 3, jim: 4
      v

    "If it does not include a defined vector": (v) ->
      assert.ok v.conflicts ['a'], sam: 2

    "If it includes all existing vectors but with a lower version": (v) ->
      assert.ok v.conflicts ['a'], sam: 1, dave: 2, bill: 3, jim: 3

    "Unless vectors are equal": (v) ->
      assert.ok !v.conflicts ['a'], sam: 1, dave: 2, bill: 3, jim: 4

    "Or greater": (v) ->
      assert.ok !v.conflicts ['a'], sam: 3, dave: 2, bill: 3, jim: 5

    "Or new": (v) ->
      assert.ok !v.conflicts ['a'], sam: 1, dave: 2, bill: 3, jim: 4, internet: 1


describe "A nested vclock"
  "When a higher scoped vclock is incremented and then a lower scoped vclock is incremented":
    topic: ->
      v = new Vclock {name: "name"}
      v.inc ['a']
      v.inc ['a', 'b']
      v

    "The higher scoped vclock should be incremented twice": (v) ->
      assert.equal v.get(['a']).name, 2

    "The lower scoped vclock should be equal to the higher": (v) ->
      assert.equal v.get(['a', 'b']).name, 2

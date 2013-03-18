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

describe "A vclock",
  "is created with vclock(node)":
    topic: -> new Vclock {name: "name"}

    "which returns an object": (s) -> assert.isObject s

describe "A vclock",
  "When incremented":
    topic: ->
      v = new Vclock {name: "name"}
      v.inc()
      v

    "increments the vector of our node": (v) ->
      assert.equal v.get('name'), 1

  "When updated":
    topic: ->
      v = new Vclock {name: "name"}
      v.inc()
      v.update dave: 1, bill: 2, jim: 1
      v.update bill: 1
      v.update jim: 2
      v

    "for new nodes, just inserts their version": (v) ->
      assert.equal v.get('dave'), 1

    "for old nodes, picks the new version if it's higher": (v) ->
      assert.equal v.get('jim'), 2

    "for old nodes, ignores the new version if it's lower": (v) ->
      assert.equal v.get('bill'), 2

    "and otherwise doesn't change any versions": (v) ->
      assert.equal v.get('name'), 1


  "When a node is removed":
    topic: ->
      v = new Vclock {name: "name"}
      v.inc()
      v.update dave: 1
      v.remove 'dave'
      v

    "Its version is removed from the vector": (v) ->
      assert.equal v.get('dave'), undefined

    "But other nodes are left intact": (v) ->
      assert.equal v.get('name'), 1

  "An update conflicts":
    topic: ->
      v = new Vclock {name: "name"}
      v.update sam: 1, dave: 2, bill: 3, jim: 4
      v

    "If it does not include a defined vector": (v) ->
      assert.ok v.conflicts sam: 2

    "If it includes all existing vectors but with a lower version": (v) ->
      assert.ok v.conflicts sam: 1, dave: 2, bill: 3, jim: 3

    "Unless vectors are equal": (v) ->
      assert.ok !v.conflicts sam: 1, dave: 2, bill: 3, jim: 4

    "Or greater": (v) ->
      assert.ok !v.conflicts sam: 3, dave: 2, bill: 3, jim: 5

    "Or new": (v) ->
      assert.ok !v.conflicts sam: 1, dave: 2, bill: 3, jim: 4, internet: 1


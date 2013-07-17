vows    = require 'vows'
assert  = require 'assert'

{Version, Versions} = require '../lib/versions'

describe = (name, bat) -> vows.describe(name).addBatch(bat).export(module)

# describe "A Version",
#   "is created with new Version(data, clock)":
#     topic: -> new Version({}, {})

#     "which returns an object": (v) -> assert.isObject v


describe "A version",
  "when you add a child":
    topic: ->
      v = new Version {a: 1, b: 2}, {clock1: 1}
      v2 = new Version {a: 3, c: 1}, {clock1: 1, clock2: 1}
      v.addChild v2
      v

    "values in the parent will be overwritten by values in the child": (v) ->
      console.log v.stack if v instanceof Error
      assert.equal v.getData().a, 3

    "values not overwritten by the child will be left alone": (v) ->
      assert.equal v.getData().b, 2

    "values introduced by the child will be added": (v) ->
      assert.equal v.getData().c, 1

    "and then add a second child with a higher version":
      topic: (v) ->
        v3 = new Version {a: 4, b: 2, d: 1}, {clock1: 1, clock2: 1, clock3: 1}
        try
          v.addChild v3
        catch e
          console.log e
        
        v

      "values in the parent will be overwritten by values in the child": (v) ->
        console.log "hi2"
        console.log v.stack if v instanceof Error
        assert.equal v.getData().a, 3

      "values not overwritten by the child will be left alone": (v) ->
        console.log "hi3"
        assert.equal v.getData().b, 2

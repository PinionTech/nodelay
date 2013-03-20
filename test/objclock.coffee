vows    = require 'vows'
assert  = require 'assert'
describe = (name, bat) -> vows.describe(name).addBatch(bat).export(module)

ObjClock = require '../lib/objclock'

describe "An ObjClock",
  "is created with new ObjClock()":
    topic: -> new ObjClock

    "which returns an object": (s) -> assert.isObject s

    "which has a constructor of 'ObjClock'": (s) -> assert.equal s.constructor?.name, 'ObjClock'

describe "An ObjClock",
  "When an update is applied on a fresh ObjClock":
    topic: ->
      v = new ObjClock
      ret = v.update {a: 1}, {n: 1}
      [v, ret]

    "the whole update is returned": ([v, ret]) ->
      assert.deepEqual ret.obj, {a: 1}

  "When two updates are applied to a fresh ObjClock":
    "and the updates do not overlap":
      topic: ->
        v = new ObjClock
        ret = [v]
        ret.push v.update {a: 1}, {n: 1}
        ret.push v.update {b: 1}, {m: 1}
        ret

      "the whole of the first update is returned": (ret) ->
        assert.deepEqual ret[1].obj, {a: 1}

      "the whole of the second update is returned": (ret) ->
        assert.deepEqual ret[2].obj, {b: 1}

    "and the updates completely overlap":
      topic: ->
        v = new ObjClock
        ret = [v]
        ret.push v.update {a: 1}, {n: 1}
        ret.push JSON.parse JSON.stringify ret[1]
        ret.push v.update {a: 2}, {n: 2}
        ret.push v.update {a: 3}, {n: 0}
        ret

      "the whole of the first update is returned": (ret) ->
        assert.deepEqual ret[2].obj, {a: 1}

      "the whole of the update with the higher vclock is returned": (ret) ->
        assert.deepEqual ret[3].obj, {a: 2}

      "the first update is pruned by the higher update": (ret) ->
        assert.deepEqual ret[1].obj, {}

      "none of the update with the lower vclock is returned (null)": (ret) ->
        assert.deepEqual ret[4], null

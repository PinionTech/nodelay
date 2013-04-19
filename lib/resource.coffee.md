Resource
--------

The Resource class provides shared state for nodes within Nodelay. The state is
represented as a large shared JSON object, scoped to the level that the node has
connected within the heirarchy. Nodes share `resource update` messages to
communicate changes to this state.

'JSON object', in this case, means an object that can be cleanly serialised and
deserialised from JSON. That is to say, no values other than object, array,
primitives, and null.

The Resource class has the following goals:

* Make modifications at a particular path in the object Provide merging and
* conflict resolution of multiple updates Allow querying to select an arbitrary
* subset of the global object Emit events when data is updated


Helper functions
----------------

> At some point these should probably move to a separate library.

**onlyChanges** returns a JSON object representing the values in `newer` that
aren't already present in `older`. This is designed to provide a minimal object
that can be merged by deepMerge.

There are a couple of serious limitations to this representation. Arrays are
problematic (how do you represent reordering or removing of elements?) and
there's no way to represent moving or copying of data, so those are expensive
operations.

The main advantage of this approach is simplicity. A more complicated patch
system would need more a complicated conflict resolution mechanism (ie you would
need to provide some kind of commutative move operation otherwise one move would
invalidate another). Maybe that's a good idea but it would add a lot of
complexity and I don't really move things very often.

    onlyChanges = (older, newer) ->
      return newer if (Array.isArray(older) or Array.isArray(newer)) and older.length != newer.length

      return (if newer == older then null else newer) if typeof older isnt 'object' or typeof newer isnt 'object' or !older or !newer

      obj = if Array.isArray(older) then [] else {}
      changed = false
      for k of newer
        if typeof older[k] is 'object' and typeof newer[k] is 'object'
          changes = onlyChanges older[k], newer[k]
          if changes
            obj[k] = changes
            changed = true
          else if Array.isArray(older)
            if Array.isArray(newer[k])
              obj[k] = newer[k]
            else
              obj[k] = {}
        else
          if newer[k] != older[k]
            obj[k] = newer[k]
            changed = true
          else if Array.isArray(older)
            obj[k] = newer[k]

      if changed then obj else null


**deepMerge** is a recurisve object merge designed to apply the results of
onlyChanges. `deepMerge(a, onlyChanges(a, b))` should return the same thing as
`deepMerge(a, b)`. Like onlyChanges, it can't deal with different-length arrays.

As an additional property, deepMerge modifies the object in-place and preserves
object and array references. This is useful because it allows us to treat
subtrees of our resource as distinct units.

    deepMerge = (dst, src) ->
      # Can't merge different-length arrays, but we zero-length it so we preserve the reference
      dst.length = 0 if Array.isArray(dst) and Array.isArray(src) and dst.length != src.length

      for k, srcv of src
        dstv = dst[k]
        if srcv is null
          delete dst[k]
        else if typeof dstv is 'object' and typeof srcv is 'object'

          # Merging two arrays
          if Array.isArray(dstv) and Array.isArray(srcv) and dstv.length == srcv.length
            deepMerge dstv, srcv

          # Merging two objects
          else if dstv isnt null and !Array.isArray(dstv) and !Array.isArray(srcv)
            deepMerge dstv, srcv

          else
            dst[k] = srcv
        else
          dst[k] = srcv
      return

    deepDelete = (dst, src) ->
      return unless src
      emptied = true
      for k, dstv of dst

        srcv = src[k]
        if srcv is null
          delete dst[k]
        else if typeof dstv is 'object' and typeof srcv is 'object'
          if (Array.isArray(dstv) and Array.isArray(srcv) and dstv.length == srcv.length) or
            (!Array.isArray(dstv) and !Array.isArray(srcv))
              subemptied = deepDelete dstv, srcv
              if subemptied
                delete dst[k]
              else
                emptied = false
          else
            delete dst[k]
        else if srcv isnt undefined
          delete dst[k]
        else
          emptied = false

      return emptied


    matches = MsgEmitter.matches



Resource class
--------------

    class Resource
      constructor: (@node, @path=[], @data={}, @versions=new Versions) ->


We start with methods that make it easy to refer to an object at a particular
location within our data. To do this we use the idea of a sub-resource. That is,
a copy of this resource at a path within the resource. Depending on our access
pattern, we use **sub** or **at** They work the same way, but **sub** creates
empty objects as necessary to make a space for an object being merged in.
**at**, on the other hand, is designed for reading data and will return null if
the path doesn't exist.

Paths can be expressed either as varargs or an array.


      at: (path) ->

      sub: (path) ->


Next we have the fundamental data access methods.

**merge** accepts an update (as in the kind we would receive in a `resource
update` message) and a version to apply the update at. It passes off the real
work to the Versions class.

      merge: (data, version) ->

        @versions.update data, version
        @dirty = true


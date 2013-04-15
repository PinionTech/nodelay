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

    clobber = (dst, src) ->
      delete dst[k] for k, v of dst
      dst[k] = src[k] for k, v of src


    matches = MsgEmitter.matches



Resource class
--------------

    class Resource
      constructor: (@node, @path=[], @data={}, @versions=new ResourceVersions) ->



We start with methods that make it easy to refer to an object at a particular
location within our data. To do this we use the idea of a sub-resource. That is,
a copy of this resource at a path within the resource. Depending on our access
pattern, we use `.sub` or `.at`. They work the same way, but `.sub` creates
empty objects as necessary to make a space for an object being merged in. `.at`,
on the other hand, is designed for reading data and will return null if the path
doesn't exist.

Paths can be expressed either as varargs or an array.


      at: (path) ->

      sub: (path) ->


Next we have the fundamental data access methods.

`.merge` is the real powerhouse of the class. It accepts an update (as in the
kind we would receive in a `resource update` message) and a version to apply
the update at.

      merge: (data, version) ->


First we call out to ResourceVersions to







Versions class
--------------

**Versions** is designed to handle conflict resolution and multiple
value management within the Resource. Conflicts in Nodelay aren't necessarily a
bad thing. For example we use conflict handling to mediate between multiple
nodes who (rightly) have different opinions about the state of a particular
resource. They don't have to know how to resolve those differences. Instead,
they allow the values to conflict and another node will resolve them into a
reasonable single value.

    class Versions

The `Versions` class starts with a single root version and a list of heads. The
root represents the complete state of data. Each version contains a number of
child versions, each one being causally connected to its parents.

The heads represent the current set of childless versions. That is, versions we
expect to receive updates about.

Recursively merging from the heads back to the root should give us all data
within the system.

      constructor: ->
        @root = new Version()
        @heads = [@root]
        @data = {}

Updates come in through the `update` function.

      update: (data, clock) ->

This function checks to see which versions the update will apply to (its
parents). If we can't find any parents to apply to, the update applies at the
root version

        parents = version.canApply clock for version in heads
        parents = [@root] if !@parents.length

We create a new version to represent the new data we've received, then notify
each parent that it has a new child.

        ver = new Version(this, parents, data)
        parent.addChild ver for parent in parents



    class Version

Versions start off as heads until they receive children with addChild.

      constructor: (@versions, @parents=[], @data={}, @clock) ->
        @isHead = true
        @children = []
        @cache = {}

When we get a new child, remove ourselves from the head list if necessary,
add the child in the appropriate position (as determined by clock ordering), and
invalidate our data cache so that the new data will appear in the next refresh.

      addChild: (child) ->
        @isHead = false

        i = @versions.heads.indexOf this
        @versions.heads.splice i, 1 if i >= 0

        @cache = {}

To update our data,

      updateData: ->
        for child in @children
          @data.merge


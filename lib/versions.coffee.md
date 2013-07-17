Versions
--------

This module is designed to handle conflict resolution and multiple value
management within a **Resource**. Conflicts in Nodelay aren't necessarily a bad
thing. For example we use conflict handling to mediate between multiple nodes
who (rightly) have different opinions about the state of a particular resource.
They don't have to know how to resolve those differences. Instead, they allow
the values to conflict and another node will resolve them into a reasonable
single value.

We use a modified vector clock/version vector structure (tentatively called
Object Clocks). Each version is represented by a clock, a mapping between
branches and versions. So an clock like `{a:1, b:2}` qualitatively means "the
first version on the a branch and the second version on the b branch".

For our purposes, these branches always correspond to nodes, so we could
simplify that to mean "**a**'s first version and **b**'s second version". We can
then use *clock ordering* to figure out which versions are causally connected to
others, like so:

* Clocks `{a:1}` and `{b:2}` are causally unconnected.
* Clock `{a:2}` is derived from `{a:1}`.
* A clock containing `{a:1, b:2}` is derived from both `{a:1}` and `{b:2}`

To resolve a conflict between **a** (at version `{a:1}`) and **b** (at version
`{b:2}`), a resolving node (say, **r**) could send data with a clock like `{a:1,
b:2, r:1}`. This would supersede **a**'s version 1 and **b**'s version 2.

Alternatively, a or b could be clever and perform conflict resolution
themselves, so **a** could send an update with `{a:2, b:2}`, which would
indicate that its update has taken into account the data from **b** at `{b:2}`
and intends to override it.

The main way our implementation differs from traditional version vectors or
vector clocks is that we don't treat updates as all-or-nothing. Each value in
the JSON Object is considered to be first-class, so an update can partially
override another update and be partially overridden in turn by other updates.

    {EventEmitter} = require('events')
    {deepMerge, deepDelete} = require('./resource')

Versions class
--------------
The **Versions** class starts with a single root version and an index of heads by
branch. The root represents the complete state of data. Each version contains a
number of child versions, each one being causally derived from its parents.

The heads represent the furthest extent of the tree. We start there when
applying updates so we can quickly identify where on the tree the new update
should attach.


    class Versions

      constructor: ->
        @root = new Version()
        @heads = {}

Updates come in through the `update` function.

      update: (data, clock) ->

        thisver = new Version(data, clock)

We try to find a point to attach at each head on the tree by selecting each
branch in the new update's clock and getting its corresponding head. Then we
walk back through the tree until we find something whose clock we can beat.

        parents = []

        for branch of clock
          version = @heads[branch]
          parent = version?.highestAttachPoint thisver, branch

          parents.push parent if parent and parent not in parents

        parents = [root] if parents.length is 0

Now we notify each parent that it has a new child, and add event listeners so we
can keep our heads up to date.

        parent.addChild ver for parent in parents

Versions start off as heads, they lose head status if they acquire children or
are collapsed, they gain head status if all their children are removed. In
reality, we don't need to remove the head if a Version acquires children,
because the children will just overwrite it. However, in the collapsing case
we do because we may have collapsed the only remaining head in a branch.

        @addHead thisver

        thisver.on 'collapsed', => @removeHead thisver
        thisver.on 'head', => @addHead thisver


      removeHead: (ver) ->
        for branch, head of heads
          delete heads[branch] if head is ver

      addHead: (ver) ->
        for branch of ver.clock
          heads[branch] = ver

Provide **getData** and **mergeData** methods for getting data back out - they
just proxy to the root Version.

      getData: -> @root.getData()

      mergeData: (data) -> @root.mergeData data


Version class
-------------

The **Version** class represents an individual version within our version tree.

    class Version extends EventEmitter

      constructor: (@data={}, @clock={}) ->
        @children = []
        @parents = []

When we get a new child, we add the child in the appropriate position (as
determined by clock ordering), and prune any of our values that have been
superseded by values in the child.

      addChild: (child) ->

Find where the child should go in the child list. We add new data with an equal
version behind old data, so data doesn't change unless it's beaten by a better
version.

        for child, i in @children
          break if @supersedes child

        @children.splice(i, 0, child)

        child.parents.push this

        @prune child.data

      prune: (data) ->
        emptied = deepDelete @data, data
        @collapse() if emptied

Find out whether this Version supersedes another Version using a vector clock
comparison. We beat the other version if we have all of its branches, and at
least one that is greater or new.

      supersedes: (other) ->
        greater = false
        for node, otherVer of other.clock
          ver = @clock[node]
          return false if !ver? or ver < otherVer
          greater = true if ver > otherVer

        return true if greater

If we've gotten this far then we have the same version of all of the other
Version's branches, so we only beat it if we have a new one.

        for node, newver of @clock
          return true if !other.clock[node]

        return false


If a node goes away for some reason, we want to collapse its data into that of
its parent. That means that in the event of multiple conflicting versions,
still-live data now will win out over data from a node that no longer exists. It
also means that in the event that a conflict-resolving node goes away, the
conflict-resolved data will be superseded by data from whichever individual node
would otherwise be winning, so the conflict-resolver won't cause data to stay
stale forever.

      collapse: ->
        @emit 'collapsed'
        parent.absorbChild this for parent in @parents

      absorbChild: (child) ->
        deepMerge @data, child.data

        if child.children
          Array.prototype.push.apply @children, child.children
        else
          @emit 'head'

To get data for this version, we start with our own data and then merge each
child's data in reverse order. This causes higher versioned data to overwrite
older data. We return this result so it can be used recursively. **getData**
returns a new object, and **mergeData** will update an existing object.

      getData: ->
        @mergeData {}

      mergeData: (data) ->
        deepMerge data, @data
        child.mergeData data for child in @children by -1
        data

**highestAttachPoint** is our helper to find where a new version can attach on the tree. We take
which branch we want to traverse and the version we need to find. If the version
beats us, then we can insert it here. Otherwise, punt the question up to the
parent we have along that branch.

      highestAttachPoint: (version, branch) ->
        if version.supersedes this
          return this
        else
          for parent in @parents
            if parent.clock[branch]
              return parent.highestAttachPoint version, branch
            else
              return null


    module.exports = {Version, Versions}

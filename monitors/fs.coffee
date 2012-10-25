util = require 'util'
path = require 'path'
fs   = require 'fs-ext'
proc = require 'procfs'
Node  = require '../lib/node'

CHECK_INTERVAL = 5000

node = Node('fs monitor').connect 'localhost', process.argv[2]

res = node.resources

oldTicks = {}

olds = {}
diff = (k, v) ->
  ret = 0
  if olds[k]
    ret = (v - olds[k]) / (CHECK_INTERVAL/1000)
  olds[k] = v
  ret

setInterval ->
  updata = {}
  proc.mounts (err, mounts) ->
    return if err
    for name, mount of mounts
      continue unless mount.device.slice(0,4) is '/dev'

      delete mount.freq
      delete mount.pass
      try
        mount.device = path.join(path.dirname(mount.device),fs.readlinkSync(mount.device))
      catch e
        # Guess it wasn't a symlink after all
      updata[name] = mount
      
      u = updata[name]
      statvfs = fs.statVFS mount.mountpoint
      kb = statvfs.f_frsize / 1024

      u.size = statvfs.f_blocks * kb
      u.free = statvfs.f_bavail * kb
      u.reserved = (statvfs.f_bfree - statvfs.f_bavail) * kb
      u.used = u.size - (statvfs.f_bfree * kb)
      u.usage = (u.used)/(u.free+u.used) if (u.free + u.used) isnt 0
      u.free_inodes = statvfs.f_favail

    res.update fs: updata

, CHECK_INTERVAL



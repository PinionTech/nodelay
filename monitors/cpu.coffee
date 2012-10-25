util = require 'util'
fs   = require 'fs'
proc = require 'procfs'
Node  = require '../lib/node'

CHECK_INTERVAL = 5000

node = Node('cpu monitor').connect 'localhost', process.argv[2]

res = node.resources

oldTicks = {}
cpustats = {}

getCPU = (cpu, factor=1) ->
  ret = {}
  old = cpustats[cpu.name]
  if old
    for k, v of cpu when typeof v is 'number'
      ret[k] = (v - old[k]) / (CHECK_INTERVAL/1000) / 100 * factor
  cpustats[cpu.name] = cpu
  ret

olds = {}
diff = (k, v) ->
  ret = 0
  if olds[k]
    ret = (v - olds[k]) / (CHECK_INTERVAL/1000)
  olds[k] = v
  ret

qw = (x) -> x.split(' ')

setInterval ->
  proc.stat (err, data) ->
    return if err
    updata =
      cpus: data.cpus
      cpu:
        total: getCPU(data.cpu, 1/data.cpus)
    
    updata.cpu[k] = getCPU v for k, v of data when k.slice(0,3) is 'cpu' and -k[3] <= 0
    updata[k] = data[k] for k in qw "procs_running procs_blocked"
    updata.cswitches = diff 'ctxt', data.ctxt
    updata.new_processes = diff 'processes', data.processes

    res.update updata

, CHECK_INTERVAL



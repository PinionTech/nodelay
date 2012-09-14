{exec, spawn} = require 'child_process'
Node  = require '../lib/node'

node = Node('port monitor').connect 'localhost', process.argv[2]

getInfo = (cb) ->
  child = spawn 'netstat', ['-utlpn']
  byProcess = {} 
  child.stdout.on 'data', (data) ->
    data = data.toString('utf8')
    for line in data.split '\n'
      fields = line.split /\s+/
      #console.log fields.length, ":", fields
      if fields[0][0] == 't'
        fields.splice(5,1)
      continue unless fields.length == 7
      #console.log "#{fields[5]} listening to #{fields[3]} on #{fields[0]}"
      pid = fields[5].split('/')[0]
      port = fields[3].split(':')
      port = port[port.length-1]
      byProcess[pid] ||= {}
      byProcess[pid][fields[0]] ||= []
      byProcess[pid][fields[0]].push port

    byProcess[23936] = {tcp: [25015], udp: [25015]}
    cb byProcess


selector = node.resource process: pid: '*'

setInterval ->
  getInfo (ports) ->
    selector.each (path, res) ->
      res.update ports: ports[res.data.process?.pid] if ports[res.data.process?.pid]
,5000

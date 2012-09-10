Node = require '../lib/node'

node = Node('childkiller').connect 'localhost', process.argv[2]

WINDOW = 12
avgs = {}

whitelabel-csgo-sydney1:
  fgscsgo1:
    12345: { cpuUsage: 0.23 }
    23456: { cpuUsage: 0.45 }
    34567: { cpuUsage: 0.67 }
  fgscsgo2:
    42345: { cpuUsage: 0.23 }
    53456: { cpuUsage: 0.45 }
    64567: { cpuUsage: 0.67 }


node.resources (res) ->
  for name, res2 of res
    if res2.children
      for cname, child of res2.children
        node.resource [cname, child], (res) ->
          child = res
          
          avgs[child.pid] ||= []
          myavgs = avgs[child.pid]
          myavgs.unshift child.cpuUsage if child.cpuUsage?
          myavgs.splice WINDOW
         
          if child.state is 'zombie'
            res.send "kill"
            res.send "info", "Killed zombie child"
           
          else if myavgs.length == WINDOW
            avg = myavgs.reduce((a, b) -> a + b) / WINDOW
            if avg >= 0.8
              res.send "kill"
              res.send "info", "Killed runaway CPU child"






node.on 'metric', ({resource, data: metrics}) ->
  return unless typeof resource is "string"
  if metrics.children
    for child in metrics.children
      avgs[child.pid] ||= []
      myavgs = avgs[child.pid]
      myavgs.unshift child.cpuUsage if child.cpuUsage?
      myavgs.splice WINDOW
     
      if child.state is 'zombie'
        node.send resource: resource, type: "kill", data: child.pid
        node.send resource: resource, type: "info", data: "Killed zombie child #{child.pid}"
       
      else if myavgs.length == WINDOW
        avg = myavgs.reduce((a, b) -> a + b) / WINDOW
        if avg >= 0.8
          node.send resource: resource, type: "kill", data: child.pid
          node.send resource: resource, type: "info", data: "Killed runaway CPU child #{child.pid} of #{resource}"
     

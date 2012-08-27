Node = require '../lib/node'

node = Node('childkiller').connect 'localhost', process.argv[2]

WINDOW = 12
avgs = {}

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
     

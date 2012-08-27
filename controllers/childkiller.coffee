Node = require '../lib/node'

node = Node('childkiller').connect 'localhost', process.argv[2]

WINDOW = 12
avgs = {}

node.on 'metric', ({resource, data: metrics}) ->
  if metrics.children
    for child in metrics.children
      avgs[child.pid] ||= []
      myavgs = avgs[child.pid]
      myavgs.unshift child.cpuUsage if child.cpuUsage?
      myavgs.splice WINDOW
     
      if child.state is 'zombie'
        node.send "kill", child.pid
        node.send "info", "Killed zombie child #{child.pid} of #{resource}"
       
      else if myavgs.length == WINDOW
        avg = myavgs.reduce((a, b) -> a + b) / WINDOW
        if avg >= 0.8
          node.send "kill", child.pid
          node.send "info", "Killed runaway CPU child #{child.pid} of #{resource}"
     

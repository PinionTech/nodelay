Node = require '../lib/node'

node = Node('childkiller').connect 'localhost', process.argv[2]

WINDOW = 12
avgs = {}

node.resource process: '*', (res) ->
  console.log res.data
  return unless res.data.process.children
  for pid, child of res.data.process.children
    
    avgs[child.pid] ||= []
    myavgs = avgs[child.pid]
    myavgs.unshift child.cpuUsage if child.cpuUsage?
    myavgs.splice WINDOW
   
    if child.state is 'zombie'
      sub = res.sub('process','children',pid)
      sub.send "kill"
      sub.send "info", "Killed zombie child"
     
    else if myavgs.length == WINDOW
      avg = myavgs.reduce((a, b) -> a + b) / WINDOW
      if avg >= 0.8
        sub = res.sub('process','children',pid)
        sub.send "kill"
        sub.send "info", "Killed runaway CPU child"

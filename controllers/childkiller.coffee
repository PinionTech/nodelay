Node = require '../lib/node'

node = Node('childkiller').connect 'localhost', process.argv[2]

WINDOW = 12
avgs = {}


node.resource process: '*', (res) ->
  return unless res.data.process?.children
  for child in res.data.process.children when child
    pid = child.pid

    avgs[pid] ||= []
    myavgs = avgs[pid]
    myavgs.unshift child.cpuUsage if child.cpuUsage?
    myavgs.splice WINDOW

    if child.state is 'zombie'
      sub = res.sub('process','children',pid)
      sub.send "kill"
      sub.send "info", "Killed zombie child"
      #FIXME: shouldn't have to do this
      delete child.state
     
    else if myavgs.length == WINDOW
      avg = myavgs.reduce((a, b) -> a + b) / WINDOW
      if avg >= 0.8
        sub = res.sub('process','children',pid)
        sub.send "kill"
        sub.send "info", "Killed runaway CPU child"
        delete avgs[pid]
        #FIXME: shouldn't have to do this
        delete child.cpuUsage
   

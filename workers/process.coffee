Service = require '../lib/service'
Node  = require '../lib/node'

services = {}

node = Node.connect 'localhost'

node.on 'add resource', ({data: service}) ->
  console.log "adding service", service 
  services[service.name] = new Service service.name, service 

node.on 'remove resource', ({data: service}) ->
  delete services[service.name]

node.on 'start', ({data: service}) -> services[service]?.start()

node.on 'stop', ({data: service}) -> services[service]?.stop()


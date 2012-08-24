repl = require 'repl'
util = require 'util'
fs = require 'fs'
Node = require '../lib/node'
opts = require('optimist')
  .usage('Usage: $0 [host]')
  .options
    p: alias: 'port', describe: "use non-default port (does not work)", default: 44445
    k: alias: 'auth-key', describe: "use auth key file"

[host] = opts.argv._

port = opts.argv.p
privkey = opts.argv.k

RED   = '\u001b[31m'
BLUE  = '\u001b[34m'
RESET = '\u001b[0m'

node = Node.connect (host or 'localhost'), port, ->
  if privkey
    node.privkey = fs.readFileSync(privkey)
    node.send type: "auth", signed: true
   

global.quiet = false

node.on '*', (msg) ->
  unless global.quiet
    process.stdout.write "\r"
    header = "[#{msg.from} #{RED}#{msg.type}#{RESET}]"
    header += "\n" if typeof msg.data is 'object'
    console.log header, util.inspect msg.data, false, 4, true
    process.stdout.write "\n" + repl.prompt + repl.rli.line

send = (type, data) ->
  node.send type, data
  header = "[#{BLUE}#{node.name} #{RED}#{type}#{RESET}]"
  header += "\n" if typeof data is 'object'
  console.log header, util.inspect data, false, 4, true
  

global[k] = v for k, v of {node, send}


repl = repl.start useGlobal: true, ignoreUndefined: true
repl.on 'exit', process.exit

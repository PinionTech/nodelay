repl = require 'repl'
util = require 'util'
coffee = require 'coffee-script'
fs = require 'fs'
Node = require '../lib/node'
opts = require('optimist')
  .usage("""
    Usage: $0 [command]
      You probably want to wrap your command in single quotes so your other quotes don't get eaten by your shell.
      If no command is specified, nodelay will open a REPL.

      Resource paths can be either "strings" or ["arrays","of","strings"] for nested resources.

    Commands:
      help              Show this message
      send TYPE, [DATA] Send a message
      send [METADATA]   Send a raw message
        eg: $0 send 'type: "hello", data: "world"'
      stream            Stream incoming messages

      resources [DEPTH]      Show current resources
      resource PATH, [DEPTH] Show specified resource
      update PATH, DATA      Merge data into specified resource
""")
  .options
    h: alias: 'host', describe: "connect to host other then localhost", default: 'localhost'
    p: alias: 'port', describe: "use non-default port", default: 44445
    k: alias: 'key', describe: "use auth key file"
    help: boolean: true, describe: "Show this message"

argv = opts.argv
args = argv._

return opts.showHelp(console.log) if argv.help

RED   = '\u001b[31m'
GREEN = '\u001b[32m'
BLUE  = '\u001b[34m'
RESET = '\u001b[0m'
node = new Node 'nodelay tool #' + Math.random().toFixed(4).slice(2)
node.connect argv.host, argv.port, ->
  if argv.key
    node.privkey = fs.readFileSync(argv.key)
    node.send type: "auth", signed: true
  start()
   

global.quiet = true
isRepl = false

printMsg = (msg) ->
  {from, type, data, resource} = msg
  resource = [resource] if typeof resource is 'string'
  process.stdout.write "\r"
  contents = util.inspect data, false, 4, true
  header = "[#{from} #{RED}#{type}#{RESET}]"
  header += " [#{GREEN}#{resource.join '>'}#{RESET}]" if resource
  header += "\n" if contents.indexOf('\n') >= 0
  console.log header, contents 

node.on '*', (msg) ->
  unless global.quiet or msg.type is 'pong'
    printMsg msg
    if isRepl
      process.stdout.write "\n" + repl.prompt + repl.rli.line

global.node = node

global.send = (type, data) ->
  msg = node.buildMsg type, data
  node.sendRaw msg
  printMsg msg
  process.exit() unless isRepl


global.update = (path, data) ->
  node.resources.sub(path).update data
  printMsg from: node.name, type: "resource update", resource: path, data: data
  process.exit() unless isRepl

showResource = (path, depth) ->
  updateTimer = null
  node.resource path, ->
    clearTimeout updateTimer
    updateTimer = setTimeout done, 500

  done = ->
    console.log util.inspect node.resources.data, false, depth, true
    process.exit() unless isRepl

  setTimeout done, 5000


global.resources = (depth=999) -> showResource {}, depth
global.resource = (resource, depth=999) -> showResource resource, depth

global.stream = ->
  global.quiet = false  
global.unstream = ->
  global.quiet = true  

help = ->
  opts.showHelp(console.log)
  

started = false
start = ->
  return if started
  started = true
  if args.length
    args[0] = args[0]+"()" if args.length is 1 and args[0].indexOf(' ') is -1
    coffee.eval args.join ' '  
  else
    isRepl = true

    repl = repl.start useGlobal: true, ignoreUndefined: true
    repl.on 'exit', process.exit

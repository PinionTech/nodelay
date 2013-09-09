repl = require 'repl'
util = require 'util'
coffee = require 'coffee-script'
fs = require 'fs'
Node = require '../lib/node'
opts = require('optimist')
  .usage("""
    Usage: $0 [command]
      If no command is specified, nodelay will open a REPL.

      Resource paths can be either strings or [arrays,of,strings] for nested resources.

      You can also use undefined commands as a shortcut. COMMAND RES ARGS becomes a
      message {type: COMMAND, resource: RES, data: ARGS}

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

printMsg = (msg, depth=999) ->
  from = if typeof msg.from is 'object' then msg.from.join('>') else msg.from
  res = if typeof msg.resource is 'object' then msg.resource?.join('>') else msg.resource
  header = "[#{from}: #{RED}#{msg.type} #{BLUE}#{res or ''}#{RESET}]"
  empty = false
  if typeof msg.data is 'object'
    empty = true
    for k of msg.data
      empty = false
      break
    header += "\n" unless empty

  process.stdout.write "\r"
  if empty
    console.log (new Date()).toISOString(), header
  else
    console.log (new Date()).toISOString(), header, util.inspect msg.data, false, depth, true

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


global.resources = (depth=999) -> showResource [], depth
global.resource = (resource, depth=999) -> showResource resource, depth

global.stream = ->
  global.quiet = false
global.unstream = ->
  global.quiet = true

help = ->
  opts.showHelp(console.log)


BUILTINS = "help resources resource send stream update".split(" ")
processArgs = (cmd, args...) ->
  if cmd in BUILTINS
    str = "#{cmd}(#{quote args})"
  else
    str = "send(type:#{quote cmd}, resource:#{quote(args[0]) or null}, data: #{quote(args[1..]) or '{}'})"

  #console.log "str", str
  return str

quote = (args) ->
  return "" unless args?
  args = [args] unless Array.isArray args
  (for arg in args
    if !isNaN(parseFloat(arg)) && isFinite(arg)
      arg
    else if match = arg.match /^\[(.*)\]$/
      "[#{quote match[1].split(',')}]"
    else if arg.match /^[\w-]*$/
      "'#{arg}'"
    else
      arg
  ).join(',')



started = false
start = ->
  return if started
  started = true
  if args.length
    coffee.eval processArgs args...
  else
    isRepl = true

    repl = repl.start useGlobal: true, ignoreUndefined: true
    repl.on 'exit', process.exit

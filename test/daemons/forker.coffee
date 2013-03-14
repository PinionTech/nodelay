{fork} = require 'child_process'

process.execPath = '../../node_modules/.bin/coffee'

for [1..10]
  fork 'simple.coffee', [], {}


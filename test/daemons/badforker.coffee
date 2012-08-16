{fork} = require 'child_process'

process.execPath = '../../node_modules/.bin/coffee' 

for [1..8]
  fork 'simple.coffee', [], {}

for [1..2]
  fork 'spinner.coffee', [], {}



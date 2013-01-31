request = require 'request'
Node = require '../lib/node'

node = Node('pagerduty worker').connect 'localhost', process.argv[2]

URL = "https://events.pagerduty.com/generic/2010-04-15/create_event.json"

node.on 'pagerduty trigger', (msg) ->
  msg.data.event_type = "trigger"
  request.post URL, json: msg.data
node.on 'pagerduty acknowledge', (msg) ->
  msg.data.event_type = "acknowledge"
  request.post URL, json:msg.data
node.on 'pagerduty resolve', (msg) ->
  msg.data.event_type = "resolve"
  request.post URL, json: msg.data

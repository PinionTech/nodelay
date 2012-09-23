nodelay = require '../nodelay'

nodelay "flood", ->
  @bind '127.0.0.1'
  @privkey 'privkey.pem'
  @scope 'flood'
  @upstream "localhost", 1234

  @workers "logger"
  @monitors "flooder"

  @resource "resource1"
    flood: true

  @resource "resource2"
    flood: true

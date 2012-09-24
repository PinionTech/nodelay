nodelay = require '../nodelay'

port = process.argv[2] or 44445
nodelay "flood-#{port}", ->
  @bind '127.0.0.1', port
  @privkey 'privkey.pem'
  @scope "flood"#-#{port}"
  @upstream "localhost", 1234

  #@workers "logger"
  @monitors "flooder"

  @resource "resource1"
    flood: true

  @resource "resource2"
    flood: true

  setInterval =>
    console.log @node.resources.data
  ,5000


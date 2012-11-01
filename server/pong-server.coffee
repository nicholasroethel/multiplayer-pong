http = require 'http'
sockjs = require 'sockjs'

pongGame = require '../common/game'
config = require '../common/config'
utils = require '../common/utils'

PongGame = pongGame.WebPongJSGame

class PongServer

  constructor: ->
    @pongConfig = config.WebPongJSConfig
    @intervalUpdaterId = null
    @clientConnections = {}
    @server = http.createServer()
    @sockServer = sockjs.createServer()
    @sockServer.on 'connection', this.on_connection
    @game = new PongGame

  on_connection: (conn) =>
    # Add the new connection to the client connection "set"
    @clientConnections[conn.id] = conn

    conn.on 'data', (message) =>
      console.log "Got message #{message}"
      if message == 'update'
        conn.write @game.state.testCount

    conn.on 'close', =>
      console.log 'Connection closed'
      delete @clientConnections[conn.id]
      if utils.isEmpty(@clientConnections) and @intervalUpdaterId?
        clearInterval @intervalUpdaterId
        @intervalUpdaterId = null
        console.log 'Stopped interval updater'

    if !@intervalUpdaterId?
      console.log @pongConfig.update.interval
      updater = =>
        this.broadcast @game.state.testCount
        @game.state.testCount += 1
      # Start the state updater
      @intervalUpdaterId = setInterval updater, @pongConfig.update.interval

  listen: ->
    @sockServer.installHandlers @server, prefix: @pongConfig.server.prefix
    @server.listen @pongConfig.server.port, @pongConfig.server.addr

  broadcast: (msg) =>
    for cid, c of @clientConnections
      c.write msg

main = ->
  console.log 'Starting Pong server...'
  pongServer = new PongServer
  pongServer.listen()

main()

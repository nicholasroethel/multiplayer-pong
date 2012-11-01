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
    @sockServer.on 'connection', this.onConnection
    @game = new PongGame

  broadcast: (msg) ->
    for cid, c of @clientConnections
      c.write msg

  listen: ->
    @sockServer.installHandlers @server, prefix: @pongConfig.server.prefix
    @server.listen @pongConfig.server.port, @pongConfig.server.addr

  onConnection: (conn) =>
    @clientConnections[conn.id] = conn

    conn.on 'data', (msg) =>
      this.onData(conn, msg)
    conn.on 'close', =>
      this.onClose(conn)

    this.setupUpdater()

  onData: (conn, msg) =>
    console.log "Got message #{msg} from #{conn.id}"
    if msg == 'update'
      conn.write @game.state.testCount

  onClose: (conn) =>
    console.log "Connection #{conn.id} closed, cleaning up"
    delete @clientConnections[conn.id]
    if utils.isEmpty(@clientConnections) and @intervalUpdaterId?
      clearInterval @intervalUpdaterId
      @intervalUpdaterId = null
    console.log "Finished cleanup of closed connection #{conn.id}"

  setupUpdater: ->
    if !@intervalUpdaterId?
      console.log @pongConfig.update.interval
      ticker = =>
        this.broadcast (new Date).getTime()
        @game.state.testCount += 1
      @intervalUpdaterId = setInterval ticker, @pongConfig.update.interval

main = ->
  console.log 'Starting Pong server...'
  pongServer = new PongServer
  pongServer.listen()

main()

http = require 'http'
sockjs = require 'sockjs'

pongGame = require '../common/game'
config = require '../common/config'
utils = require '../common/utils'
message = require '../common/message'

PongGame = pongGame.WebPongJSGame
Message = message.WebPongJSMessage

class PongServer

  constructor: ->
    @config = config.WebPongJSConfig
    @intervalUpdaterId = null
    @clientConnections = {}
    @server = http.createServer()
    @sockServer = sockjs.createServer()
    @sockServer.on 'connection', this.onConnection
    @game = new PongGame @config
    @handlers =
      init: this.onInit,
      update: this.onUpdate,
      action: this.onAction,

  broadcast: (type, msg) ->
    for cid, c of @clientConnections
      c.write (new Message type, msg).stringify()

  listen: ->
    @sockServer.installHandlers @server, prefix: @config.server.prefix
    @server.listen @config.server.port, @config.server.addr

  onConnection: (conn) =>
    @clientConnections[conn.id] = conn

    conn.on 'data', (msg) =>
      this.onData conn, msg
    conn.on 'close', =>
      this.onClose conn

    this.setupUpdater()
    @game.start()

  onData: (conn, msg) =>
    console.log "Got message #{msg} from #{conn.id}"
    msg = Message.parse msg
    handler = @handlers[msg.type]
    if handler?
      handler conn, msg.data

  onInit: (conn, data) =>
    conn.write (new Message 'init', (new Date).getTime()).stringify()

  onUpdate: (conn, data) =>
    conn.write (new Message 'update', @game.state).stringify()

  onAction: (conn, data) =>
    console.log 'on action!'

  onClose: (conn, data) =>
    console.log "Connection #{conn.id} closed, cleaning up"
    delete @clientConnections[conn.id]
    if utils.isEmpty(@clientConnections) and @intervalUpdaterId?
      clearInterval @intervalUpdaterId
      @intervalUpdaterId = null
    console.log "Finished cleanup of closed connection #{conn.id}"
    @game.stop()

  setupUpdater: ->
    if !@intervalUpdaterId?
      console.log @config.update.interval
      ticker = =>
        this.broadcast 'tick', @game.state.lastUpdate
      @intervalUpdaterId = setInterval ticker, @config.update.syncTime

main = ->
  console.log 'Starting Pong server...'
  pongServer = new PongServer
  pongServer.listen()

main()

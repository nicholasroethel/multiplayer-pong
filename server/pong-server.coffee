http = require 'http'
sockjs = require 'sockjs'
_ = require 'underscore'

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
      moveUp: this.onMoveUp,
      moveDown: this.onMoveDown

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

    connCount = _.keys(@clientConnections).length

    if connCount == 2
      # 2 players, start game
      this.setupUpdater()
      @game.start()
    else if connCount > 2
      conn.write (new Message 'close', reason: '2 players already joined')
      conn.close()

  onData: (conn, msg) =>
    console.log "Got message #{msg} from #{conn.id}"
    msg = Message.parse msg
    handler = @handlers[msg.type]
    if handler?
      handler conn, msg.data

  onInit: (conn, data) =>
    if _.keys(@clientConnections).length == 1
      block = 'left'
    else
      block = 'right'
    conn.write (new Message 'init',
      timestamp: (new Date).getTime(),
      block: block
    ).stringify()

  onUpdate: (conn, data) =>
    conn.write (new Message 'update', @game.state).stringify()

  onMoveUp: (conn, data) =>
    console.log 'move up'

  onMoveDown: (conn, data) =>
    console.log 'move down'

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

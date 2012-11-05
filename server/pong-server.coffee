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
  @NEEDED_PLAYERS: 2

  constructor: ->
    @config = config.WebPongJSConfig
    @players = {}
    @httpServer = http.createServer()
    @sockServer = sockjs.createServer()
    @sockServer.on 'connection', this.onConnection
    @game = new PongGame @config
    @handlers =
      init: this.onInit,
      update: this.onUpdate,
      moveUp: this.onMoveUp,
      moveDown: this.onMoveDown
    @updaterId = null

  listen: ->
    @sockServer.installHandlers @httpServer,
      prefix: @config.server.prefix
    @httpServer.listen @config.server.port,
      @config.server.addr

  # SockJS connection handlers
  onConnection: (conn) =>
    if this.playerCount() >= @NEEDED_PLAYERS
      this.send conn, 'close', 'Cannot join. Game is full'
      conn.close()
    else
      conn.on 'data', this.onData
      conn.on 'close', this.onClose
      this.addPlayer conn
      if this.playerCount() == @NEEDED_PLAYERS
        console.log 'Got 2 players. Starting game'
        this.send conn, 'start', null
        this.setupUpdater()
        @game.start()

  onData: (conn, msg) =>
    console.log "Got message #{msg} from #{conn.id}"
    msg = Message.parse msg
    handler = @handlers[msg.type]
    if handler?
      handler conn, msg.data

  onClose: (conn, data) =>
    console.log "Connection #{conn.id} closed"
    this.removePlayer conn
    this.stopUpdater()
    @game.stop()
    this.broadcast 'drop', null
    console.log "Game stopped, due to player connection #{conn.id} drop"

  # Message handlers
  onInit: (conn, data) =>
    block = @players[conn.id].block
    this.send 'init',
      timestamp: (new Date).getTime(),
      block: block

  onUpdate: (conn, data) =>
    this.send conn 'update', @game.state

  onMoveUp: (conn, data) =>
    @game.state.blocks[@players[conn.id].block].moveUp()
    this.broadcast 'update', @game.state

  onMoveDown: (conn, data) =>
    @game.state.blocks[@players[conn.id].block].moveDown()
    this.broadcast 'update', @game.state

  # Connection helper methods
  send: (conn, msgType, msgData) =>
    conn.write (new Message msgType, msgData).stringify()

  broadcast: (type, msg) ->
    for cid, p of @players
      this.send p.connection, type, msg

  # Players management
  addPlayer: (conn) ->
    @players[conn.id] =
      connection: conn,
      block: ['left', 'right'][this.playerCount()]

  removePlayer: (conn) ->
    delete @players[conn.id]

  playerCount: ->
    _.keys(@players).length

  # Periodic client updates
  setupUpdater: ->
    if !@updaterId is null
      @updaterId = setInterval this.broadcastState,
        @config.update.syncTime

  broadcastState: =>
    this.broadcast 'update', @game.state.lastUpdate

  stopUpdater: ->
    if @updaterId?
      clearInterval @updaterId
      @updaterId = null

main = ->
  console.log 'Starting Pong Server'
  pongServer = new PongServer
  pongServer.listen()

main()

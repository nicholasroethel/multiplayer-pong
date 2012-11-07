http = require 'http'
sockjs = require 'sockjs'
_ = require 'underscore'

pongGame = require '../common/game'
config = require '../common/config'
message = require '../common/message'

PongGame = pongGame.WebPongJSServerGame
Message = message.WebPongJSMessage

class PongServer
  @NEEDED_PLAYERS: 2

  constructor: ->
    @config = config.WebPongJSConfig
    @players = {}
    @httpServer = http.createServer()
    @sockServer = sockjs.createServer()
    try
      @game = new PongGame @config
    catch e
      console.error "Could not create new game using configuration #{@config}"
      throw e
    @handlers =
      init: this.onInit,
      input: this.onInput
    @updaterId = null
    @availableBlockIds = [0, 1]
    @lastBroadcast = (new Date).getTime()

  listen: ->
    @sockServer.installHandlers @httpServer,
      prefix: @config.server.prefix
    @sockServer.on 'connection', this.onConnection
    @httpServer.on 'error', (e) =>
      console.error "Error running http server on #{@config.server.addr}:#{@config.server.port} #{e}"
    @httpServer.listen @config.server.port, @config.server.addr

  # SockJS connection handlers
  onConnection: (conn) =>
    console.log "New connection #{conn.id} opened"
    if this.playerCount() >= PongServer.NEEDED_PLAYERS
      console.log "Rejected connection #{conn.id} due to full game"
      this.send conn, 'close', 'Cannot join. Game is full'
      conn.close()
    else
      this.addPlayer conn
      console.log "Added connection #{conn.id}. Player count: #{this.playerCount()}"
      conn.on 'data', this.onData conn
      conn.on 'close', this.onClose conn

  onData: (conn) =>
    (msg) =>
      console.log "Got message #{msg} from #{conn.id}"
      msg = Message.parse msg
      handler = @handlers[msg.type]
      if handler?
        handler conn, msg.data

  onClose: (conn) =>
    =>
      console.log "Connection #{conn.id} closed"
      this.removePlayer conn
      this.stopUpdater()
      @game.stop()
      this.broadcast 'drop', null
      console.log "Game stopped, due to player connection #{conn.id} drop"

  # Message handlers
  onInit: (conn, data) =>
    block = @players[conn.id].block
    this.send conn, 'init',
      timestamp: (new Date).getTime(),
      block: block
    if this.playerCount() == PongServer.NEEDED_PLAYERS
      console.log "Got #{PongServer.NEEDED_PLAYERS} players. Starting the game"
      this.broadcast 'start', null
      this.setupUpdater()
      @game.start()
    else
      console.log "Waiting for #{PongServer.NEEDED_PLAYERS - this.playerCount()} more players"

  onInput: (conn, data) =>
    @game.addInputUpdate @players[conn.id].block, data

  # Connection helper methods
  send: (conn, msgType, msgData) =>
    try
      msg = (new Message msgType, msgData).stringify()
    catch e
      console.error "Could not serialize message: type:#{msgType}, data:#{msgData} for sending to #{conn.id}"
    try
      conn.write msg
    catch e
      console.error "Could not send message #{msg} to #{conn.id}: #{e}"

  broadcast: (type, msg) ->
    for cid, p of @players
      this.send p.connection, type, msg

  broadcastState: =>
    @lastBroadcast = (new Date).getTime()
    console.log "Broadcasting state"
    for cid, p of @players
      this.send p.connection, 'update',
        state: @game.state
        inputIndex: p.inputIndex

  # Player management methods
  addPlayer: (conn) ->
    @players[conn.id] =
      connection: conn
      block: @availableBlockIds.pop()
      inputUpdates: []
      inputIndex: -1

  removePlayer: (conn) ->
    @availableBlockIds.push @players[conn.id].block
    delete @players[conn.id]

  playerCount: ->
    _.keys(@players).length

  # Periodic client updates
  setupUpdater: ->
    if !@updaterId?
      @updaterId = setInterval this.broadcastState, @config.update.syncTime

  stopUpdater: ->
    if @updaterId?
      clearInterval @updaterId
      @updaterId = null

exports.PongServer = PongServer

main = ->
  console.log 'Starting Pong Server'
  pongServer = new PongServer
  pongServer.listen()

main() if require.main is module

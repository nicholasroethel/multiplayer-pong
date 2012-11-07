exports = window

Message = exports.WebPongJSMessage

class Client

  @KEYS:
    up: 38,
    down: 40,
    j: 74,
    k: 75,

  @SERVERUPDATES: 100

  constructor: (@conf, @game, @board) ->
    @serverUpdates = []
    @inputsBuffer = []
    @inputIndex = 0
    @blockName = null
    @context = @board.getContext '2d'
    @controlledBlock = null
    @initialDrift = null
    @messageBoard = document.getElementById(@conf.messageBoard.id)
    @callbacks =
      init: this.onInit,
      start: this.onStart,
      update: this.onUpdate,
      drop: this.onDrop

  start: (@sock) ->
    @sock = @sock ? new SockJS "http://#{@conf.server.addr}:#{@conf.server.port}#{@conf.server.prefix}"
    @sock.onmessage = (e) =>
      try
        msg = Message.parse(e.data)
      catch e
        console.error "Error parsing message from server: #{e}"
        throw e

      handler = @callbacks[msg.type]
      if handler?
        handler msg
      else
        console.error "Ignoring unknown message #{msg}"

    @sock.onopen = =>
      this.userMessage 'Connected to server'
      this.send 'init', null

    @sock.onclose = =>
      this.userMessage 'Server closed the connection. Refresh the page to try again'
      @game.stop()

  onInit: (msg) =>
    @initialDrift = Number(msg.data.timestamp) - (new Date).getTime()
    @blockName = msg.data.block
    @controlledBlock = @game.state.blocks[msg.data.block]
    this.userMessage 'Waiting for other player'

  onStart: (msg) =>
    @game.start @initialDrift
    @game.on 'update', this.onGameUpdate
    @game.on 'game over', this.onGameOver
    document.onkeydown = this.onKeyDown
    document.onkeyup = this.onKeyUp
    this.userMessage "Game running. Use the keyboard to control the #{@blockName} block"

  onUpdate: (msg) =>
    @serverUpdates.push msg.data
    # Delete old updates which we should not be needing
    if @serverUpdates.length > Client.SERVERUPDATES
      @serverUpdates.splice(0, 1)
    this.discardAcknowledgedInput msg.data
    # Set position by authorative server
    @controlledBlock = msg.data.state.blocks[@blockName].y
    @game.processInputs @controlledBlock, @inputsBuffer, @inputIndex

  discardAcknowledgedInput: (serverUpdate) ->
    @inputsBuffer = (input for input in @inputsBuffer when input.index > serverUpdate.inputIndex)

  onDrop: (msg) =>
    @game.stop()
    this.userMessage 'Other player dropped. Waiting for a new player to connect'

  send: (msgType, msgData) ->
    @sock.send (new Message msgType, msgData).stringify()

  userMessage: (msg) ->
    @messageBoard.innerHTML = msg

  onKeyDown: (ev) =>
    switch ev.keyCode
      when Client.KEYS.up, Client.KEYS.k
        @controlledBlock.movingUp = 1
        this.send 'moveUp', 'start'
      when Client.KEYS.down, Client.KEYS.j
        @controlledBlock.movingDown = 1
        this.send 'moveDown', 'start'

  onKeyUp: (ev) =>
    switch ev.keyCode
      when Client.KEYS.up, Client.KEYS.k
        this.send 'moveUp', 'stop'
        @controlledBlock.movingUp = 0
      when Client.KEYS.down, Client.KEYS.j
        this.send 'moveDown', 'stop'
        @controlledBlock.movingDown = 0

  drawLeftBlock: (y) ->
    @context.beginPath()
    @context.fillStyle = @conf.block.left.color
    @context.fillRect 0, y, @conf.block.size.x, @conf.block.size.y
    @context.closePath()
    @context.fill()

  drawRightBlock: (y) ->
    @context.beginPath()
    @context.fillStyle = @conf.block.right.color
    @context.fillRect @conf.board.size.x - @conf.block.size.x, y,
      @conf.block.size.x, @conf.block.size.y
    @context.closePath()
    @context.fill()

  drawBall: (x, y) ->
    @context.beginPath()
    @context.fillStyle = @conf.ball.color
    @context.arc x, y, @conf.ball.radius, 0, 2 * Math.PI, false
    @context.closePath()
    @context.fill()

  onGameUpdate: (ev, state) =>
    #this.processInput()
    this.magic()
    this.drawState ev, state

  magic: ->
    updateCount = @serverUpdates.length

    if updateCount == 0
      # No updates from the server yet
      return

    now = (new Date).getTime() - @game.drift

    # By default use the first update
    prev = next = @serverUpdates[0]

    # Find our
    if updateCount >= 2
      i = _.find [1..updateCount-1], (i) =>
        @serverUpdates[i-1].state.lastUpdate <= now <= @serverUpdates[i].state.lastUpdate
      if i?
        prev = @serverUpdates[i-1]
        next = @serverUpdates[i]

    # Get the wand.
    t = (next.state.lastUpdate - now) / (next.state.lastUpdate - prev.state.lastUpdate + 0.01)

    # Magic!
    # No, seriously. This does interpolation of the 2 server positions we're between
    @game.lerp prev.state, next.state, t

  processInput: ->
    inputs = []
    if @controlledBlock.movingUp
      inputs.push 'up'
    if @controlledBlock.movingDown
      inputs.push 'down'
    if inputs.length > 0
      @inputIndex += 1
      inputEntry =
        buffer: inputs,
        index: inputIndex
      @inputsBuffer.push inputEntry
      this.send 'input', inputEntry

  drawState: (ev, state) =>
    @context.clearRect 0, 0, @board.width, @board.height
    this.drawBall state.ball.x, state.ball.y
    this.drawLeftBlock state.blocks.left.y
    this.drawRightBlock state.blocks.right.y

  onGameOver: (ev, data) =>
    # Temp placeholder
    window.alert 'Game over!'

exports.WebPongJSClient = Client

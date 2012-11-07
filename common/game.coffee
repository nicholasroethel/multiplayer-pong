exports = exports ? this

if require?
  _ = require 'underscore'
else
  _ = window._

class Game
  # An abstract base class representing a game.
  # See subclasses for client/server differences

  constructor: (@conf) ->
    @state = this.initialState()
    @callbacks = {}
    @playIntervalId = null
    @currentTime = (new Date()).getTime()

  initialState: ->
    centerY = @conf.board.size.y / 2 - @conf.block.size.y / 2
    ball: new Ball(@conf.ball.radius + 1, @conf.ball.radius + 1, @conf.ball.radius,
      @conf.ball.xVelocity, @conf.ball.yVelocity),
    blocks: [(new Block 0, centerY, @conf.block.size.x, @conf.block.size.y),
      (new Block @conf.board.size.x - @conf.block.size.x, centerY, @conf.block.size.x, @conf.block.size.y)],
    lastUpdate: null

  cloneState: (other) ->
    ball: new Ball(other.ball.x, other.ball.y, other.ball.radius,
      other.ball.xVelocity, other.ball.yVelocity)
    blocks:
      [new Block(b.x, b.y, b.width, b.height) for b in other.blocks]
    lastUpdate: other.lastUpdate

  start: (drift) ->
    drift = drift ? 0
    @state.lastUpdate = (new Date).getTime() - drift
    gameUpdate = =>
      this.play drift
    @playIntervalId = setInterval gameUpdate, 5 # Every 5 ms.

  stop: ->
    console.log 'stop'
    clearInterval @playIntervalId
    @playIntervalId = null
    # @state = this.initialState()
    # this.publish 'update', @state

  play: (drift) ->
    throw "play is not implemented in abstract base class Game"

  update: (state) ->
    @state.lastUpdate = state.lastUpdate
    @state.ball.update state.ball
    for b, i in @state.blocks
      b.update state.blocks[i]
    this.publish 'update', @state

  on: (event, callback) ->
    if not (event of @callbacks)
      @callbacks[event] = []
    @callbacks[event].push callback

  publish: (event, data) ->
    if event of @callbacks
      for callback in @callbacks[event]
        callback(event, data)

class ServerGame extends Game
  # A Game subclass implementing the server-side logic

  constructor: (conf) ->
    super conf
    @inputUpdates = []

  play: (drift) ->
    # The server just loops through the game
    # Executing user commands if necessary
    currentTime = (new Date()).getTime()
    timeDelta = currentTime - @state.lastUpdate

    if timeDelta >= @conf.update.interval
      # Apply all the client input from the buffer
      this.processInputs()

      # Run the game, and publish the update
      @state.ball.pongMove timeDelta, @state.blocks, @conf.board.size.x, @conf.board.size.y
      @state.lastUpdate = currentTime
      this.publish 'update', @state

  processInputs: ->
    # Apply all the inputs that users have sent since last update, then empty
    # all the buffers and update the input index, which is a global identifier
    # for input commands.
    for blockId, updateEntry of @inputUpdates
      if updateEntry.updates.length > 0
        block = @state.blocks[blockId]
        for input in updateEntry.updates
          for cmd in input.buffer
            if cmd == 'down'
              block.moveDown input.duration, @conf.board.size.y
            else if cmd == 'up'
              block.moveUp input.duration
        # We just processed these, so clear the buffer, and move the input index
        updateEntry.inputIndex = (_.last updateEntry.updates).index
        updateEntry.updates = []

  addInputUpdate: (blockId, data) ->
    # The input will be processed in the next game update loop.
    @inputUpdates[blockId] = @inputUpdates[blockId] ? { updates: [], inputIndex: -1 }
    @inputUpdates[blockId].updates.push data

class ClientGame extends Game

  # Maximum server updates to buffer
  @SERVERUPDATES: 100

  constructor: (conf) ->
    super conf
    @blockId = null
    @inputsBuffer = []
    @inputIndex = 0
    @serverUpdates = []

  play: (drift) ->
    # Compute the game state in the past, as specified by @conf.client.latency,
    # so we can interpolate between the two server updates `now` falls between.
    currentTime = (new Date).getTime() - drift - @conf.client.interpLatency
    timeDelta = currentTime - @state.lastUpdate

    # Time to update
    if timeDelta >= @conf.update.interval
      # Get any input from the client, send to server
      this.sampleInput timeDelta
      # Client-side input prediction
      this.inputPredict()
      @state.ball.pongMove timeDelta, @state.blocks, @conf.board.size.x, @conf.board.size.y
      this.interpolateState currentTime
      @state.lastUpdate = currentTime
      this.publish 'update', @state

  inputPredict: ->
    # Client-side input prediction:
    #
    # - Get latest position of our controlled block according to the server
    # - Re-apply all inputs not yet acknowledged by the server. They are
    # contained in `@inputsBuffer`.
    #
    # More info at:
    # https://developer.valvesoftware.com/wiki/Latency_Compensating_Methods_in_Client/Server_In-game_Protocol_Design_and_Optimization#Client_Side_Prediction

    if @serverUpdates.length > 0
      # Start from last known position
      this.controlledBlock().y = (_.last @serverUpdates).state.blocks[@blockId].y

    # "Replay" all user input that is not yet acknowledged by the server
    for input in @inputsBuffer
      for dir in input.buffer
        this.controlledBlock().move dir, input.duration, [@conf.board.size.y, @confi.board.size.x][dir]
        switch cmd
          when 'up'
            this.controlledBlock().moveUp input.duration
          when 'down'
            this.controlledBlock().moveDown input.duration, @conf.board.size.y

  interpolateState: (now) ->
    updateCount = @serverUpdates.length
    if updateCount < 2
      return

    # Find the 2 updates `now` falls between.
    i = _.find [1..updateCount-1], (i) =>
      @serverUpdates[i-1].state.lastUpdate <= now <= @serverUpdates[i].state.lastUpdate

    if not i?
      console.log 'Could not interpolate'
      return

    prev = @serverUpdates[i-1].state
    next = @serverUpdates[i].state

    # Linearly interpolate the position of the ball in an attempt to smooth
    # movement for the clients
    lerp = (p, n, t) ->
      p + (n - p) * Math.max(Math.min(t, 1), 0)

    # Compute the fraction used for interpolation. This is a number between 0
    # and 1 that represents the fraction of time passed (at the current moment, `now`)
    # between the two neighbouring updates.
    t = (now - prev.lastUpdate) / (next.lastUpdate - prev.lastUpdate)

    @state.ball.x = lerp prev.ball.x, next.ball.x, t
    @state.ball.y = lerp prev.ball.y, next.ball.y, t

    # Interpolate the block that we are not controlling
    for block, blockId in @state.blocks
      if blockId != blockId
        block.y = lerp prev.blocks[blockId].y, next.blocks[blockId].y, t

  sampleInput: (timeDelta) ->
    # Sample the user input, package it up and send it to the server
    # The input index is a unique identifier of the input sample.
    inputs = []
    if this.controlledBlock().movingUp
      inputs.push 'up'
    if this.controlledBlock().movingDown
      inputs.push 'down'
    if inputs.length > 0
      @inputIndex += 1
      inputEntry =
        buffer: inputs
        index: @inputIndex
        duration: timeDelta
      console.log "Sending update to server", inputEntry
      @inputsBuffer.push inputEntry
      this.publish 'input', inputEntry

  addServerUpdate: (update) ->
    # Buffer up an update that the server has sent us
    @serverUpdates.push update

    # Keep only the last `ClientGame.SERVERUPDATES` server updates
    if @serverUpdates.length > ClientGame.SERVERUPDATES
      @serverUpdates.splice(0, 1)

    # Forget about updates that the server has acknowledged
    this.discardAcknowledgedInput update

  discardAcknowledgedInput: (serverUpdate) ->
    @inputsBuffer = (input for input in @inputsBuffer when input.index > serverUpdate.inputIndex)

  setBlock: (@blockId) ->

  controlledBlock: ->
    if @blockId?
      @state.blocks[@blockId]

class Block

  constructor: (@x, @y, @width, @height) ->
    @movingUp = 0
    @movingDown = 0

  update: (data) ->
    @x = data.x
    @y = data.y
    @width = data.width
    @height = data.height

  top: ->
    @y

  bottom: ->
    @y + @height

  left: ->
    @x

  right: ->
    @x + @width

  moveUp: (t) ->
    @y = Math.max(@y - t*0.5, 0)

  moveDown: (t, maxY) ->
    @y = Math.min(@y + t*0.5, maxY - @height)

class Ball

  constructor: (@x, @y, @radius, @xVelocity, @yVelocity) ->

  update: (data) ->
    @x = data.x
    @y = data.y
    @xVelocity = data.xVelocity
    @yVelocity = data.yVelocity
    @radius = data.radius

  # Bounce this ball off a block if needed
  blockPong: (block) ->
    bounce = x: false, y: false

    # Block borders
    left = block.left()
    right = block.right()
    up = block.top()
    down = block.bottom()

    xWithin = block.left() <= @x + @radius <= block.right() or
      block.left() <= @x - @radius <= block.right()

    yWithin = block.top() <= @y + @radius <= block.bottom() or
      block.top() <= @y - @radius <= block.bottom()

    if yWithin
      if @xVelocity > 0
        # Moving right, check left border
        if Math.abs(@x-left) <= @radius
          bounce.x = true
      else
        if Math.abs(@x-right) <= @radius
          bounce.x = true

    if xWithin
      if @yVelocity > 0
        # Moving down, check up border
        if Math.abs(@y-up) <= @radius
          bounce.y = true
      else
        # Moving up, check down border
        if Math.abs(@y-down) <= @radius
          bounce.y = true

    return bounce

  horizontalWallCollision: (maxY) ->
    @y - @radius <= 0 or @y + @radius >= maxY

  verticalWallCollision: (maxX) ->
    @x - @radius <= 0 or @x + @radius >= maxX

  verticalPong: ->
    @yVelocity = -@yVelocity

  horizontalPong: ->
    @xVelocity = -@xVelocity

  left: ->
    @x - @radius

  right: ->
    @x + @radius

  top: ->
    @y - @radius

  bottom: ->
    @y + @radius

  # Collision-aware movement of the ball
  pongMove: (timeDelta, blocks, boardX, boardY) ->

    this.move timeDelta

    for block in blocks
      bounce = this.blockPong block
      if bounce.x or bounce.y
        this.moveBack timeDelta
        if bounce.x
          this.horizontalPong()
        if bounce.y
          this.verticalPong()
        this.move timeDelta
        return

    if this.horizontalWallCollision boardY
      this.moveBack timeDelta
      this.verticalPong()
      this.move timeDelta
    else if this.verticalWallCollision boardX
      this.moveBack timeDelta
      this.horizontalPong()
      this.move timeDelta

  # Free movement of the ball
  move: (t) ->
    @x += @xVelocity * t
    @y += @yVelocity * t

  moveBack: (t) ->
    this.move -t


exports.WebPongJSServerGame = ServerGame
exports.WebPongJSClientGame = ClientGame
exports.WebPongJSBall = Ball
exports.WebPongJSBlock = Block

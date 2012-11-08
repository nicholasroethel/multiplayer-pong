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
    # Blocks are initially vertically centered, ball is at top right corner
    centerY = @conf.board.size.y / 2 - @conf.block.size.y / 2
    ball: new Ball(@conf.ball.radius + 1, @conf.ball.radius + 1, @conf.ball.radius,
      @conf.ball.xVelocity, @conf.ball.yVelocity)
    blocks: [(new Block 0, centerY, @conf.block.size.x, @conf.block.size.y),
      (new Block @conf.board.size.x - @conf.block.size.x, centerY, @conf.block.size.x, @conf.block.size.y)]
    lastUpdate: null

  cloneState: (other) ->
    x =
      ball: new Ball(other.ball.x, other.ball.y, other.ball.radius,
        other.ball.xVelocity, other.ball.yVelocity)
      blocks:
        b.clone() for b in other.blocks
      lastUpdate: other.lastUpdate

  start: (drift) ->
    drift = drift ? 0
    @state.lastUpdate = (new Date).getTime() - drift
    gameUpdate = =>
      this.play drift
    @playIntervalId = setInterval gameUpdate, @conf.client.timerAccuracy

  stop: ->
    console.log 'stop'
    clearInterval @playIntervalId
    @playIntervalId = null

  play: (drift) ->
    throw "play is not implemented in abstract base class Game"

  # Collision-aware movement of the ball
  pongMove: (timeDelta, blocks, boardX, boardY) ->
    ball = @state.ball

    ball.move timeDelta

    for block in blocks
      bounce = this.blockPong block
      if bounce.x or bounce.y
        ball.moveBack timeDelta
        if bounce.x
          ball.horizontalPong()
        if bounce.y
          ball.verticalPong()
        ball.move timeDelta
        return

    if ball.horizontalWallCollision boardY
      ball.moveBack timeDelta
      ball.verticalPong()
      ball.move timeDelta
    else if ball.verticalWallCollision boardX
      ball.moveBack timeDelta
      ball.horizontalPong()
      ball.move timeDelta

  # Collision detect and bounce this ball off a block if needed Note that this
  # doesn't work in the general case. For example, in theory if the block is
  # moving too fast the ball could get "stuck inside it".  But it works well
  # enough for our purposes.
  blockPong: (block) ->
    ball = @state.ball

    # Wheter ball and block are horizontally aligned
    xWithin = block.left() <= ball.right() <= block.right() or
      block.left() <= ball.left() <= block.right() or
      ball.left() <= block.left() <= block.right() <= ball.right()

    # Wheter ball and block are vertically aligned
    yWithin = block.top() <= ball.bottom() <= block.bottom() or
      block.top() <= ball.top() <= block.bottom() or
      ball.top() <= block.top() <= block.bottom() <= ball.bottom()

    bounce  = {}
    bounce.x = yWithin and
      ((ball.xVelocity > 0 and Math.abs(ball.x-block.left()) <= ball.radius) or
      (ball.xVelocity < 0 and Math.abs(ball.x-block.right()) <= ball.radius))

    bounce.y = xWithin and
      ((ball.yVelocity > 0 and Math.abs(ball.y-block.top()) <= ball.radius) or
      (ball.yVelocity < 0 and Math.abs(ball.y-block.bottom()) <= ball.radius))

    return bounce

  horizontalWallCollision: (maxY) ->
    @state.ball.top() <= 0 or @state.ball.bottom() >= maxY

  verticalWallCollision: (maxX) ->
    @state.ball.left() <= 0 or @state.ball.right() >= maxX

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
      this.pongMove timeDelta, @state.blocks, @conf.board.size.x, @conf.board.size.y
      @state.lastUpdate = currentTime
      this.publish 'update', @state

  processInputs: ->
    # Apply all the inputs that users have sent since last update, then empty
    # all the buffers and update the input index, which is a global identifier
    # for input commands.
    for blockId, updateEntry of @inputUpdates when updateEntry.updates.length > 0
        block = @state.blocks[blockId]
        for input in updateEntry.updates
          for cmd in input.buffer
            block.move cmd, input.duration, @conf.board.size.y
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
    # so we can interpolate between the two server updates `currentTime` falls between.
    currentTime = (new Date).getTime() - drift - @conf.client.interpLatency
    timeDelta = currentTime - @state.lastUpdate

    # Time to update.
    if timeDelta >= @conf.update.interval
      # Get any input from the client, send to server
      this.sampleInput timeDelta
      # Client-side input prediction
      this.inputPredict()
      this.pongMove timeDelta, @state.blocks, @conf.board.size.x, @conf.board.size.y
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
        this.controlledBlock().move dir, input.duration, @conf.board.size.y

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

    # Interpolate only the block that we are not controlling
    for block, blockId in @state.blocks
      if blockId != @blockId
        block.y = lerp prev.blocks[blockId].y, next.blocks[blockId].y, t

  sampleInput: (timeDelta) ->
    # Sample the user input, package it up and publish it.
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

  clone: ->
    new Block(@x, @y, @width, @height)

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

  move: (dir, duration, maxValue) ->
    switch dir
      when 'down'
        this.moveDown duration, maxValue
      when 'up'
        this.moveUp duration, maxValue
      else
        throw "Block can only move up and down, not #{dir}"

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

  # Free movement of the ball
  move: (t) ->
    @x += @xVelocity * t
    @y += @yVelocity * t

  moveBack: (t) ->
    this.move -t

  horizontalWallCollision: (maxY) ->
    this.top() <= 0 or this.bottom() >= maxY

  verticalWallCollision: (maxX) ->
    this.left() <= 0 or this.right() >= maxX

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


exports.WebPongJSServerGame = ServerGame
exports.WebPongJSClientGame = ClientGame
exports.WebPongJSBall = Ball
exports.WebPongJSBlock = Block

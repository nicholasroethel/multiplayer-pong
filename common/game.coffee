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

  initialState: ->
    # Blocks are initially vertically centered, ball is at top right corner
    objects = this.initialObjects()
    ball: new Ball objects.ball.x, objects.ball.y, @conf.ball.radius, objects.ball.xVelocity, objects.ball.yVelocity
    blocks: new Block block.x, block.y, @conf.block.size.x, @conf.block.size.y for block in objects.blocks
    lastUpdate: null
    score: [0, 0]

  initialObjects: ->
    centerY = @conf.board.size.y / 2 - @conf.block.size.y / 2
    ball:
      x: @conf.ball.radius + 1
      y: @conf.ball.radius + 1
      xVelocity: @conf.ball.xVelocity
      yVelocity: @conf.ball.yVelocity
    blocks: [
      {x: 0, y: centerY},
      {x: @conf.board.size.x - @conf.block.size.x, y: centerY}
    ]

  resetBall: ->
    objects = this.initialObjects()
    @state.ball.x = objects.ball.x
    @state.ball.y = objects.ball.y
    @state.ball.xVelocity = objects.ball.xVelocity
    @state.ball.yVelocity = objects.ball.yVelocity
    this.publish 'reset', null

  cloneState: (other) ->
    x =
      ball: new Ball(other.ball.x, other.ball.y, other.ball.radius,
        other.ball.xVelocity, other.ball.yVelocity)
      blocks:
        b.clone() for b in other.blocks
      lastUpdate: other.lastUpdate
      score: _.clone other.score

  start: (drift) ->
    drift = drift ? 0
    @state.lastUpdate = (new Date).getTime() - drift
    gameUpdate = =>
      this.play drift
    @playIntervalId = setInterval gameUpdate, @conf.update.timerAccuracy

  stop: ->
    console.log 'Game stopped'
    clearInterval @playIntervalId
    @playIntervalId = null

  play: (drift) ->
    throw "play is not implemented in abstract base class Game"

  pongMove: (timeDelta) ->
    @state.ball.move timeDelta
    this.collisionCheck timeDelta

  # Collision check for current state
  # Corrects the state if needed
  collisionCheck: (timeDelta) ->
    ball = @state.ball
    blocks = @state.blocks
    collision = false

    for block in blocks
      bounce = this.blockPong block
      if bounce.x or bounce.y
        collision = true
        ball.moveBack timeDelta

        if bounce.x
          ball.horizontalPong()
        if bounce.y
          ball.verticalPong()

        unless @conf.demoMode
          # Increase the ball horizontal speed based on its distance to the
          # middle of the block -- hitting it closer the block corners will
          # produce more acceleartion.
          blockMiddle = block.height / 2
          # This is a number between 0 and 1
          distToMiddle = (Math.abs(ball.y - (block.top() + blockMiddle)) - ball.radius) / blockMiddle
          ball.horizontalAccelerate @conf.ball.accelerationFromPaddle * distToMiddle
        ball.move timeDelta

        # No need to check other block
        break

    if this.horizontalWallCollision()
      collision = true
      ball.moveBack timeDelta
      ball.verticalPong()
      ball.move timeDelta

    playerPoint = this.checkForPoint()
    if playerPoint?
      collision = true
      if @conf.demoMode
        ball.moveBack timeDelta
        ball.horizontalPong()
        ball.move timeDelta
      else
        this.onPoint playerPoint

    return collision

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

    bounce =
      x: yWithin and
        ((ball.xVelocity > 0 and Math.abs(ball.x-block.left()) <= ball.radius) or
        (ball.xVelocity < 0 and Math.abs(ball.x-block.right()) <= ball.radius))
      y: xWithin and
        ((ball.yVelocity > 0 and Math.abs(ball.y-block.top()) <= ball.radius) or
        (ball.yVelocity < 0 and Math.abs(ball.y-block.bottom()) <= ball.radius))

    return bounce

  horizontalWallCollision: ->
    @state.ball.top() <= 0 or @state.ball.bottom() >= @conf.board.size.y

  # Check if the current state is a new point situation.
  # Return the number of the player which scored a point
  # 1 means point for right player
  # 0 means point for left player
  checkForPoint: ->
    if @state.ball.left() <= 0
      1
    else if @state.ball.right() >= @conf.board.size.x
      0
    else
      null

  onPoint: (playerPoint) ->
    @state.score[playerPoint] += 1
    this.resetBall()

  update: (state) ->
    @state.lastUpdate = state.lastUpdate
    @state.ball.update state.ball
    for b, i in @state.blocks
      b.update state.blocks[i]
    @state.score = _.clone state.score
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
    @inputUpdates = [this.initialInputUpdate(), this.initialInputUpdate()]

  initialInputUpdate: ->
    updates: []
    inputIndex: -1

  play: (drift) ->
    # This is the body of the server game loop.

    # The server just loops through the game
    # Executing user commands if necessary
    currentTime = (new Date()).getTime()
    timeDelta = currentTime - @state.lastUpdate

    if timeDelta >= @conf.update.interval
      # Apply all the client input from the buffer
      this.processInputs()
      # Run the game, and publish the update
      this.pongMove timeDelta
      @state.lastUpdate = currentTime
      this.publish 'update', @state

  processInputs: ->
    # Apply all the inputs that users have sent since last update, then empty
    # all the buffers and update the input index, which is a global identifier
    # for input commands.
    for updateEntry, blockId in @inputUpdates when updateEntry.updates.length > 0
        block = @state.blocks[blockId]
        for input in updateEntry.updates
          for cmd in input.buffer
            block.move cmd, input.duration, @conf.board.size.y
        # We just processed these, so clear the buffer, and move the input index
        updateEntry.inputIndex = (_.last updateEntry.updates).index
        updateEntry.updates = []

  addInputUpdate: (blockId, data) ->
    # The input will be processed in the next game update loop.
    @inputUpdates[blockId].updates.push data

  inputIndex: (blockId) ->
    @inputUpdates[blockId].inputIndex

class ClientGame extends Game

  # Maximum server updates to buffer
  @SERVERUPDATES: 100

  constructor: (conf) ->
    super conf
    @blockId = null
    @serverUpdates = []
    @inputsBuffer = []
    @inputIndex = 0

  play: (drift) ->
    # This is the body of the client game loop.

    currentTime = (new Date).getTime() - drift
    if @conf.client.interpolate
      # Compute the game state in the past, as specified by
      # @conf.client.latency, so we can interpolate between the two server
      # updates `currentTime` falls between.
      currentTime -= @conf.client.interpLatency

    timeDelta = currentTime - @state.lastUpdate

    # Time to update.

    if timeDelta >= @conf.update.interval
    
      # Get any input from the client, send to server
      this.sampleInput timeDelta

      # Client-side input prediction
      this.inputPredict()

      # if statements that check for how we should interpolate
      if !@conf.client.interpolate
        this.noInterpolation currentTime
        this.collisionCheck timeDelta
      else if @conf.client.optimizedLinearInterpolate
        this.optimizedLinearInterpolation currentTime
        this.collisionCheck timeDelta
      else if @conf.client.regularLinearInterpolate
        this.regularLinearInterpolation currentTime
        this.collisionCheck timeDelta

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

    # If we're not interpolating, we use our local position to start prediction
    if @conf.client.interpolate
      # Start from last known position
      this.controlledBlock().y = (_.last @serverUpdates).state.blocks[@blockId].y

    # "Replay" all user input that is not yet acknowledged by the server
    for input in @inputsBuffer
      for dir in input.buffer
        this.controlledBlock().move dir, input.duration, @conf.board.size.y
        unless @conf.client.interpolate
          input.buffer = []

  regularLinearInterpolation: (now) ->
    updateCount = @serverUpdates.length
    if updateCount < 2
      return

    # Find the 2 updates `now` falls between.
    i = _.find [1..updateCount-1], (i) =>
      @serverUpdates[i-1].state.lastUpdate <= now <= @serverUpdates[i].state.lastUpdate

    unless i?
      console.log "Cannot interpolate. Client time #{now}, last server update at #{(_.last @serverUpdates).state.lastUpdate}"
      return

    prev = @serverUpdates[i-1].state
    next = @serverUpdates[i].state

    # Un-optimized linear interpolation of the position of the ball in an attempt to smooth
    # movement for the clients. 
    # This is the imprecise method which does not guarantee v is v1 when t is 1
    # due to floating-point arithmetic error
    # This form may be used when the hardware has a native fused multiply-add instruction.
    # Source: https://en.wikipedia.org/wiki/Linear_interpolation
    lerp = (p, n, t) ->
      p + t * (n - p)

    # Compute the fraction used for interpolation. This is a number between 0
    # and 1 that represents the fraction of time passed (at the current moment, `now`)
    # between the two neighbouring updates.
    t = (now - prev.lastUpdate) / (next.lastUpdate - prev.lastUpdate)

    if Math.max(Math.abs(prev.ball.x - next.ball.x), Math.abs(prev.ball.y - next.ball.y)) <= @conf.client.maxInterp
      @state.ball.x = lerp prev.ball.x, next.ball.x, t
      @state.ball.y = lerp prev.ball.y, next.ball.y, t

    # Interpolate only the block that we are not controlling
    for block, blockId in @state.blocks when blockId isnt @blockId
      block.y = lerp prev.blocks[blockId].y, next.blocks[blockId].y, t

    @state.score = prev.score
    this.publish 'point', @state.score

  optimizedLinearInterpolation: (now) ->
    updateCount = @serverUpdates.length
    if updateCount < 2
      return

    # Find the 2 updates `now` falls between.
    i = _.find [1..updateCount-1], (i) =>
      @serverUpdates[i-1].state.lastUpdate <= now <= @serverUpdates[i].state.lastUpdate

    unless i?
      console.log "Cannot interpolate. Client time #{now}, last server update at #{(_.last @serverUpdates).state.lastUpdate}"
      return

    prev = @serverUpdates[i-1].state
    next = @serverUpdates[i].state

    # Optimized linear interpolation of the position of the ball in an attempt to smooth
    # movement for the clients. 
    # This is the precise method that guarantees v is v1 when t is 1.
    # However, it can not be used when the hardware has a native fused multiply-add instruction.
    # Source: https://en.wikipedia.org/wiki/Linear_interpolation
    lerp = (p, n, t) ->
      (1 - t) * p + (t * n)

    # Compute the fraction used for interpolation. This is a number between 0
    # and 1 that represents the fraction of time passed (at the current moment, `now`)
    # between the two neighbouring updates.
    t = (now - prev.lastUpdate) / (next.lastUpdate - prev.lastUpdate)

    if Math.max(Math.abs(prev.ball.x - next.ball.x), Math.abs(prev.ball.y - next.ball.y)) <= @conf.client.maxInterp
      @state.ball.x = lerp prev.ball.x, next.ball.x, t
      @state.ball.y = lerp prev.ball.y, next.ball.y, t

    # Interpolate only the block that we are not controlling
    for block, blockId in @state.blocks when blockId isnt @blockId
      block.y = lerp prev.blocks[blockId].y, next.blocks[blockId].y, t

    @state.score = prev.score
    this.publish 'point', @state.score

  noInterpolation: (now) ->
    updateCount = @serverUpdates.length
    if updateCount < 2
      return

    # Find the 2 updates `now` falls between.
    i = _.find [1..updateCount-1], (i) =>
      @serverUpdates[i-1].state.lastUpdate <= now <= @serverUpdates[i].state.lastUpdate

    unless i?
      console.log "Cannot interpolate. Client time #{now}, last server update at #{(_.last @serverUpdates).state.lastUpdate}"
      return

    prev = @serverUpdates[i-1].state
    next = @serverUpdates[i].state


    # Compute the time difference that will be used 
    # This is a number between 0 and 1
    # It represents the time passed between now and the last update
    t = (now - prev.lastUpdate) / (next.lastUpdate - prev.lastUpdate)

    # Update the ball state - without interopolation
    if Math.max(Math.abs(prev.ball.x - next.ball.x), Math.abs(prev.ball.y - next.ball.y)) <= @conf.client.maxInterp
      @state.ball.x = next.ball.x
      @state.ball.y = next.ball.y

    # Update block that we are not controlling - without interpolation
    for block, blockId in @state.blocks when blockId isnt @blockId
      block.y = next.blocks[blockId].y

    @state.score = prev.score
    this.publish 'point', @state.score

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
    if @conf.client.interpolate
      # Buffer up an update that the server has sent us
      @serverUpdates.push update

      # Keep only the last `ClientGame.SERVERUPDATES` server updates
      if @serverUpdates.length > ClientGame.SERVERUPDATES
        @serverUpdates.splice(0, 1)
    else
      this.update update.state

    # Forget about input actions that the server has acknowledged
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

  horizontalAccelerate: (dxv) ->
    if @xVelocity > 0
      @xVelocity += dxv
    else
      @xVelocity -= dxv

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

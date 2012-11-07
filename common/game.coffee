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
      @conf.ball.xVelocity, @conf.ball.yVelocity)
    blocks:
      left: new Block 0, centerY, @conf.block.size.x, @conf.block.size.y
      right: new Block @conf.board.size.x - @conf.block.size.x, centerY, @conf.block.size.x, @conf.block.size.y
    lastUpdate: null

  cloneState: (other) ->
    ball: new Ball(other.ball.x, other.ball.y, other.ball.radius,
      other.ball.xVelocity, other.ball.yVelocity)
    blocks:
      left: new Block(other.blocks.left.x, other.blocks.left.y,
        other.blocks.width, other.blocks.height)
      right: new Block(other.blocks.right.x, other.blocks.right.y,
        other.blocks.width, other.blocks.height)
    lastUpdate: other.lastUpdate

  start: (drift) ->
    drift = drift ? 0
    @state.lastUpdate = (new Date).getTime() - drift
    gameUpdate = =>
      this.play drift
    @playIntervalId = setInterval gameUpdate, 1 # Every ms.

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
    @state.blocks.left.update state.blocks.left
    @state.blocks.right.update state.blocks.right
    this.publish 'update', @state

  getBlocks: ->
    [@state.blocks.left, @state.blocks.right]

  on: (event, callback) ->
    if not (event of @callbacks)
      @callbacks[event] = []
    @callbacks[event].push callback

  publish: (event, data) ->
    if event of @callbacks
      for callback in @callbacks[event]
        callback(event, data)


class Block

  constructor: (@x, @y, @width, @height) ->
    @movingUp = 0
    @movingDown = 0

  update: (data) ->
    @x = data.x
    @y = data.y
    @width = data.width
    @height = data.height

  borderUp: ->
    @y

  borderDown: ->
    @y + @height

  borderLeft: ->
    @x

  borderRight: ->
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
    left = block.borderLeft()
    right = block.borderRight()
    up = block.borderUp()
    down = block.borderDown()

    xWithin = block.borderLeft() <= @x + @radius <= block.borderRight() or
      block.borderLeft() <= @x - @radius <= block.borderRight()

    yWithin = block.borderUp() <= @y + @radius <= block.borderDown() or
      block.borderUp() <= @y - @radius <= block.borderDown()

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

  # Pong-aware movement
  pongMove: (timeDelta, leftBlock, rightBlock, boardX, boardY) ->

    this.move timeDelta

    for block in [leftBlock, rightBlock]
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

class ServerGame extends Game

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

      @state.ball.pongMove timeDelta, @state.blocks.left, @state.blocks.right, @conf.board.size.x, @conf.board.size.y
      @state.lastUpdate = currentTime
      this.publish 'update', @state

  processInputs: ->
    for blockName, updateEntry of @inputUpdates
      if updateEntry.updates.length > 0
        block = @state.blocks[blockName]
        for input in updateEntry.updates
          for cmd in input.buffer
            if cmd == 'down'
              block.moveDown input.duration, @conf.board.size.y
            else if cmd == 'up'
              block.moveUp input.duration
            console.log block.y

        # We just processed these, so clear the buffer,
        # and move the index
        updateEntry.inputIndex = (_.last updateEntry.updates).index
        updateEntry.updates = []
        console.log "Done. new index is #{updateEntry.inputIndex}"

  addInputUpdate: (blockName, data) ->
    # Adds an input update that affects `block`.
    # The input will be processed in the next game update loop.
    @inputUpdates[blockName] = @inputUpdates[blockName] ? { updates: [], inputIndex: -1 }
    @inputUpdates[blockName].updates.push data

class ClientGame extends Game

  @SERVERUPDATES: 100

  constructor: (conf) ->
    super conf
    @blockName = null
    @controlledBlock = null
    @inputsBuffer = []
    @inputIndex = 0
    @serverUpdates = []

  play: (drift) ->
    # Compute the game state in the past, as specified by @conf.client.latency,
    # so we can interpolate between the two server updates `now` falls between.
    currentTime = (new Date).getTime() - drift - @conf.client.latency
    timeDelta = currentTime - @state.lastUpdate

    # Time to update
    if timeDelta >= @conf.update.interval
      # Get any input from the client, send to server
      this.sampleInput timeDelta
      # Client-side prediction
      this.inputPredict()
      @state.ball.pongMove timeDelta, @state.blocks.left, @state.blocks.right, @conf.board.size.x, @conf.board.size.y

      # Use the buffered
      #this.interpolateState currentTime

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
    lastUpdate = _.last @serverUpdates
    if lastUpdate?
      # Start from last known position
      @controlledBlock.y = lastUpdate.state.blocks[@blockName].y

    # "Replay" all user input that is not yet acknowledged by the server
    for input in @inputsBuffer
      for cmd in input.buffer
        switch cmd
          when 'up'
            @controlledBlock.moveUp input.duration
          when 'down'
            @controlledBlock.moveDown input.duration, @conf.board.size.y

  interpolateState: (now) ->
    updateCount = @serverUpdates.length

    if updateCount == 0
      # No updates from the server yet
      return

    # By default use the first update
    prev = next = @serverUpdates[0]

    if updateCount >= 2
      # Find the 2 updates `now` falls between.
      i = _.find [1..updateCount-1], (i) =>
        @serverUpdates[i-1].state.lastUpdate <= now <= @serverUpdates[i].state.lastUpdate
      if i?
        prev = @serverUpdates[i-1]
        next = @serverUpdates[i]

    # Compute the fraction used for interpolation. This is a number between 0
    # and 1 that represents the fraction of time passed (at the current moment, `now`)
    # between the two neighbouring updates.
    t1 = (next.state.lastUpdate - now) / (next.state.lastUpdate - prev.state.lastUpdate + 0.01)
    t2 = (now - prev.state.lastUpdate) / (next.state.lastUpdate - prev.state.lastUpdate + 0.01)

    # Compute next game state using interpolation
    this.lerp prev.state, next.state, t1, t2

  sampleInput: (timeDelta) ->
    # Sample the user input, package it up and send it to the server
    # The input index is a unique identifier of the input sample.
    inputs = []
    if @controlledBlock.movingUp
      inputs.push 'up'
    if @controlledBlock.movingDown
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

  # Calculates the game state using linear interpolation given known previous
  # and next states.
  lerp: (prev, next, t1, t2) ->
    # XXX: replace @conf.update.interval with actual time passed since last
    # update
    @state = this.statelerp @state, (this.statelerp prev, next, t1), t2
    console.log @state.ball.x, @state.ball.y

  statelerp: (prev, next, t) ->
    lerp = (p, n) ->
      res = p + (Math.max(0, Math.min(1, t))) * (n - p)

    newState = this.cloneState prev

    # Interpolate
    for axis in ['x', 'y']
      newState.ball[axis] = lerp prev.ball[axis], next.ball[axis]

    for blockName in ['left', 'right']
      if blockName != @blockName
        newState.blocks[blockName].y = lerp prev.blocks[blockName].y, next.blocks[blockName].y, t

    newState

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

  setBlock: (@blockName) ->
    @controlledBlock = @state.blocks[@blockName]

exports.WebPongJSServerGame = ServerGame
exports.WebPongJSClientGame = ClientGame
exports.WebPongJSBall = Ball
exports.WebPongJSBlock = Block

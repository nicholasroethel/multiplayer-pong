exports = exports ? this

class Game

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
    currentTime = (new Date()).getTime() - drift
    timeDelta = currentTime - @state.lastUpdate
    if timeDelta >= @conf.update.interval
      for block in this.getBlocks()
        # XXX: This, of course, is stupid.
        # Should instead have a "move" property with a numerical value (<0 for
        # moving up, >0 for moving down)
        for i in [0...block.movingUp]
          block.moveUp()
        for i in [0...block.movingDown]
          block.moveDown()
      @state.ball.pongMove timeDelta, @state.blocks.left, @state.blocks.right, @conf.board.size.x, @conf.board.size.y
      @state.lastUpdate = currentTime
      this.publish 'update', @state

  update: (state) ->
    @state.lastUpdate = state.lastUpdate
    @state.ball.update state.ball
    @state.blocks.left.update state.blocks.left
    @state.blocks.right.update state.blocks.right
    this.publish 'update', @state

  # Calculates the game state using linear interpolation given known previous
  # and next states.
  lerp: (prev, next, t) ->
    # XXX: replace @conf.update.interval with actual time passed since last
    # update
    @state = this.statelerp @state, (this.statelerp prev, next, t), @conf.update.interval

  getBlocks: ->
    [@state.blocks.left, @state.blocks.right]

  statelerp: (prev, next, t) ->
    lerp = (p, n) ->
      p + (Math.max(0, Math.min(1, t))) * (n - p)
    newState = this.cloneState prev
    for b in ['left', 'right']
      newState.blocks[b].y = lerp prev.blocks[b].y, next.blocks[b].y
    for axis in ['x', 'y']
      newState.ball[axis] = lerp prev.ball[axis], next.ball[axis]
    newState

  on: (event, callback) ->
    if not (event of @callbacks)
      @callbacks[event] = []
    @callbacks[event].push callback

  publish: (event, data) ->
    if event of @callbacks
      for callback in @callbacks[event]
        callback(event, data)

  processInputs: (block, inputUpdates, inputIndex) ->
    block.movingUp = block.movingDown = 0
    for input in inputUpdates
      if input.index > inputIndex
        for m in input.buffer
          if m == 'up'
            block.movingUp += 1
          else if m == 'down'
            block.movingDown += 1

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

  moveUp: ->
    @y = Math.max(@y - 10, 0)

  moveDown: (maxY) ->
    @y = Math.min(@y + 10, maxY - @height)

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

exports.WebPongJSGame = Game
exports.WebPongJSBall = Ball
exports.WebPongJSBlock = Block

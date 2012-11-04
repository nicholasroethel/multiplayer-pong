exports = exports ? this

class Game

  constructor: (@conf) ->
    @state = this.initialState()
    @callbacks = {}
    @playIntervalId = null

  initialState: ->
    centerY = @conf.board.size.y / 2 - @conf.block.size.y / 2
    ball: new Ball(@conf.ball.radius + 1, @conf.ball.radius + 1, @conf.ball.radius,
      @conf.ball.xVelocity, @conf.ball.yVelocity)
    blocks:
      height: 20
      left: new Block 0, centerY, @conf.block.size.x, @conf.block.size.y
      right: new Block @conf.board.size.x - @conf.block.size.x, centerY, @conf.block.size.x, @conf.block.size.y
    lastUpdate: null

  start: ->
    @state.prevUpdate = (new Date).getTime()
    gameUpdate = =>
      this.play()
      this.publish 'update', @state
    @playIntervalId = setInterval gameUpdate, @conf.update.interval

  stop: ->
    console.log 'stop'
    clearInterval @playIntervalId
    @playIntervalId = null
    # @state = this.initialState()
    this.publish 'update', @state

  play: ->
    @state.lastUpdate = (new Date).getTime()
    timeDelta = @state.lastUpdate - @state.prevUpdate
    @state.prevUpdate = @state.lastUpdate
    @state.ball.pongMove timeDelta, @state.blocks.left, @state.blocks.right, @conf.board.size.x, @conf.board.size.y


  update: (@state) ->
    @state.lastUpdate = (new Date).getTime()

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

  borderUp: ->
    @y

  borderDown: ->
    @y + @height

  borderLeft: ->
    @x

  borderRight: ->
    @x + @width

class Ball

  constructor: (@x, @y, @radius, @xVelocity, @yVelocity) ->

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

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
    @stopped = true
    clearInterval @playIntervalId
    @playIntervalId = null
    # @state = this.initialState()
    this.publish 'update', @state

  play: ->
    @state.lastUpdate = (new Date).getTime()
    timeDelta = @state.lastUpdate - @state.prevUpdate
    @state.ball.move timeDelta
    @state.prevUpdate = @state.lastUpdate

    if (@state.ball.blockCollision @state.blocks.left) or (@state.ball.blockCollision @state.blocks.right)
      @state.ball.moveBack timeDelta
      @state.ball.horizontalPong()
      @state.ball.move timeDelta
    else if @state.ball.horizontalWallCollision @conf.board.size.y
      @state.ball.moveBack timeDelta
      @state.ball.verticalPong()
      @state.ball.move timeDelta
    else if @state.ball.verticalWallCollision @conf.board.size.x
      @state.ball.moveBack timeDelta
      @state.ball.horizontalPong()
      @state.ball.move timeDelta

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

  blockCollision: (block) ->
    # Check wheter the ball is in collision with the given block.
    #
    # *-----> x
    # |
    # |
    # |
    # V y
    #                           ___<--- block.boderUp()
    #                          |   |
    #    block.borderLeft()--->|   |<--- block.borderRight()
    #                          |   |
    #                          |___|
    #                            ^--- block.boderDown()
    #              _T_
    #             /   \
    #           L|  C  |R    C(@x, @y) - center
    #             \_ _/|
    #               B  |
    #               |  |
    #               <-->
    #                @radius
    #
    # This method checks wheter:
    #
    # o The center of the ball is inside the block
    # OR
    # o The distance from C to each of the block borders is less than the ball radius.
    #   - For horizontal walls, at least one of T and B is between block.borderUp() and block.borderDown()
    #   - For vertical walls, at least one of L and R is between block.borderLeft() and block.borderRight()
    if block.borderLeft() <= @x <= block.borderRight() and block.borderUp() <= @y <= block.borderDown()
      # Circle center is inside the rectangle
      return true

    # Use lambdas in hopes of taking advantage of the short-circuit for logical
    # operators to avoid unnecessary computations, but without making the code
    # too unreadable.
    distX = =>
      Math.min(Math.abs(@x - block.borderLeft()), Math.abs(@x - block.borderRight()))
    xWithin = =>
      block.borderLeft() <= @x + @radius <= block.borderRight() or
        block.borderLeft() <= @x - @radius <= block.borderRight()

    distY = =>
      Math.min(Math.abs(@y - block.borderUp()), Math.abs(@y - block.borderDown()))
    yWithin = =>
      block.borderUp() <= @y + @radius <= block.borderDown() or
        block.borderUp() <= @y - @radius <= block.borderDown()

    return distX() < @radius and yWithin() or distY() < @radius and xWithin()

  horizontalWallCollision: (maxY) ->
    @y - @radius <= 0 or @y + @radius >= maxY

  verticalWallCollision: (maxX) ->
    @x - @radius <= 0 or @x + @radius >= maxX

  verticalPong: ->
    @yVelocity = -@yVelocity

  horizontalPong: ->
    @xVelocity = -@xVelocity

  move: (t) ->
    @x += @xVelocity * t
    @y += @yVelocity * t

  moveBack: (t) ->
    this.move -t

exports.WebPongJSGame = Game
exports.WebPongJSBall = Ball
exports.WebPongJSBlock = Block

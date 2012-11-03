exports = exports ? this

class Ball

  constructor: (@x, @y, @radius, @xVelocity, @yVelocity) ->


  blockCollision: (block) ->
    # Check wheter the ball is in collision with the given block.
    # This is a general purpose method
    #
    # *-----> x
    # |       
    # |        
    # |       
    # V y
    #
    #                           ___<--- block.boderUp()
    #                          |   |
    #    block.borderLeft()--->|   |<--- block.borderRight()
    #                          |   |
    #                          |___|
    #                            ^--- block.boderDown()
    #              ___
    #             /   \
    #            |  *  |  * (@x, @y) - center
    #             \_|_/|
    #               |  |
    #               <-->
    #                @radius
    #
    xWithin = block.borderLeft() <= @x <= block.borderRight()
    yWithin = block.borderUp() <= @y <= block.borderDown()
    if xWithin and yWithin
      # Short circuit. Circle center is inside the rectangle
      return true
    if xWithin
      return Math.min(Math.abs(@x - block.borderLeft()), Math.abs(@x - block.borderRight())) <= @radius
    if yWithin
      return Math.min(Math.abs(@y - block.borderUp()), Math.abs(@x - block.borderDown())) <= @radius
    return false

  horiznotalWallCollision: (maxY) ->
    @y + @radius <= 0 or @y + @radius >= maxY

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

class Game

  constructor: (@conf) ->
    @state = this.initialState()
    @callbacks = {}
    @playIntervalId = null

  initialState: ->
    centerY = @conf.board.size.y / 2 - @conf.block.size.y / 2

    ball: new Ball(@conf.ball.radius, @conf.ball.radius, @conf.ball.radius,
      @conf.ball.xVelocity, @conf.ball.yVelocity)
    blocks:
      height: 20
      left: new Block 0, centerY, @conf.block.size.x, @conf.block.size.y
      right: new Block @conf.board.size.x - @conf.block.size.x, centerY, @conf.block.size.x, @conf.block.size.y
    lastUpdate: null

  setState: (@state) ->

  start: ->
    gameUpdate = =>
      this.play()
      this.publish 'update', @state
    @playIntervalId = setInterval gameUpdate, @conf.update.interval

  stop: ->
    clearInterval @playIntervalId
    @playIntervalId = null
    @state = this.initialState()

  play: ->
    @state.lastUpdate = (new Date).getTime()

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

exports.WebPongJSGame = Game
exports.WebPongJSBall = Ball
exports.WebPongJSBlock = Block

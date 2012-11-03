exports = exports ? this

class Ball

  constructor: (@x, @y, @radius, @xVelocity, @yVelocity) ->

  blockCollision: (block) ->
    true

  borderUp: ->
    @y - @radius

  borderDown: ->
    @y + @radius

  borderLeft: ->
    @x - @radius

  borderRight: ->
    @x + @radius

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
    blockY = @conf.board.size.y / 2 - @conf.block.size.y / 2

    ball: new Ball(@conf.ball.radius, @conf.ball.radius, @conf.ball.radius,
      @conf.ball.xVelocity, @conf.ball.yVelocity)
    blocks:
      height: 20
      left: new Block 0, blockY, @conf.block.size.x, @conf.block.size.y
      right: new Block @conf.board.size.x - @conf.block.size.x, blockY, @conf.block.size.x, @conf.block.size.y
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

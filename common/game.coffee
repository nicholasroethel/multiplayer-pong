exports = exports ? this

class Game

  constructor: (@conf) ->
    @state = this.initialState()
    @callbacks = {}
    @playIntervalId = null

  initialState: ->
    ball:
      position: x: 0, y: 0
      velocity: x: 0.4, y: 0.5
    blocks:
      height: 20
      left:
        y: @conf.board.size.y / 2 - @conf.block.size.y / 2
      right:
        y: @conf.board.size.y / 2 - @conf.block.size.y / 2
    lastUpdate: null

  setState: (@state) ->

  start: ->
    gameUpdate = =>
      this.play()
      this.publish 'update', @state
    @playIntervalId = setInterval(gameUpdate, @conf.update.interval)

  stop: ->
    clearInterval @playIntervalId
    @playIntervalId = null
    @state = this.initialState()

  play: ->
    newX = @state.ball.position.x + @conf.update.interval * @state.ball.velocity.x
    newY = @state.ball.position.y + @conf.update.interval * @state.ball.velocity.y

    if newX >= @conf.board.size.x or newX <= 0
      this.stop()
      this.publish 'game over'
      console.log 'Game over'
      return

    if newY >= @conf.board.size.y or newY <= 0
      @state.ball.velocity.y = - @state.ball.velocity.y
      newY = @state.ball.position.y + @conf.update.interval * @state.ball.velocity.y

    @state.ball.position.x = newX
    @state.ball.position.y = newY
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

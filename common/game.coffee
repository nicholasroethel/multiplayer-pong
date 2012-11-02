exports = exports ? this

class Game

  constructor: (@updateInterval) ->
    @state =
      ball:
        position: x: 0, y: 0
        velocity: x: 0.4, y: 0.5
      blocks:
        height: 20
        left:
          y: 0
        right:
          y: 0
      lastUpdate: null
    @playIntervalId = null

  setState: (@state) ->

  start: (updateCallback=null) ->
    gameUpdate = =>
      this.play()
      if updateCallback?
        updateCallback this.state
    @playIntervalId = setInterval(gameUpdate, @updateInterval)

  stop: ->
    clearInterval(@playIntervalId)
    @playIntervalId = null

  play: ->
    newX = @state.ball.position.x + @updateInterval * @state.ball.velocity.x
    newY = @state.ball.position.y + @updateInterval * @state.ball.velocity.y

    if newX >= 600 or newX <= 0
      this.stop()
      console.log 'Game over'
      return

    if newY >= 400 or newY <= 0
      @state.ball.velocity.y = - @state.ball.velocity.y
      newY = @state.ball.position.y + @updateInterval * @state.ball.velocity.y

    @state.ball.position.x = newX
    @state.ball.position.y = newY
    @state.lastUpdate = (new Date).getTime()

  update: (@state) ->
    @state.lastUpdate = (new Date).getTime()

  setLeftBlockPosition: (y) ->
    @state.blocks.left.y = y

  setRightBlockPosition: (y) ->
    @state.blocks.right.y = y

  setBallPosition: (x, y) ->
    @state.ball.position.x = x
    @state.ball.position.y = y

exports.WebPongJSGame = Game

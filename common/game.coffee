exports = exports ? this

class Game

  @initialState:
    ball:
      position: x: 0, y: 0
      velocity: x: 0.01, y: 0.005
    blocks:
      height: 20
      left:
        y: 0
      right:
        y: 0
    lastUpdate: null
    # A simple counter for testing syncrhonization;
    # will be removed.
    testCount: 0

  constructor: (updateInterval) ->
    @state = Game.initialState
    @updateInterval = updateInterval
    @playIntervalId = null

  setState: (@state) ->

  start: ->
    @playIntervalId = setInterval(this.play, @updateInterval)

  stop: ->
    clearInterval(@playIntervalId)
    @playIntervalId = null

  play: =>
    @state.ball.position.x += @updateInterval * @state.ball.velocity.x
    @state.ball.position.y += @updateInterval * @state.ball.velocity.y
    @state.lastUpdate = (new Date).getTime()
    console.log @state.ball.position.x, @state.ball.position.y

  update: (@state) ->
    @state.lastUpdate = (new Date).getTime()

exports.WebPongJSGame = Game

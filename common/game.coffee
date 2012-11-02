exports = exports ? this

class Game

  @initialState:
    ball:
      position: x: 0, y: 0
      velocity: x: 0.1, y: 0.05
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

  constructor: (@updateInterval) ->
    @state = Game.initialState
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
    @state.ball.position.x += @updateInterval * @state.ball.velocity.x
    @state.ball.position.y += @updateInterval * @state.ball.velocity.y
    @state.lastUpdate = (new Date).getTime()

  update: (@state) ->
    @state.lastUpdate = (new Date).getTime()

  setBallPosition: (x, y) ->
    @state.ball.position.x = x
    @state.ball.position.y = y

  setLeftBlockPosition: (y) ->
    @state.blocks.left.y = y

  setRightBlockPosition: (y) ->
    @state.blocks.right.y = y

exports.WebPongJSGame = Game

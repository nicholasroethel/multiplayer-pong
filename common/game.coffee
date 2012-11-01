exports = exports ? this

class Game

  @initialState:
    ball:
      position: x: 0, y: 0
    blocks:
      height: 20
      left:
        y: 0
      right:
        y: 0
    # A simple counter for testing syncrhonization;
    # will be removed.
    testCount: 0

  @defaultUpdateInterval: 1000

  constructor: (state=null, updateInterval=null) ->
    @state = state or Game.initialState
    @updateInterval = updateInterval or Game.defaultUpdateInterval
    @playIntervalId = null

  setState: (@state) ->

  start: ->
    @playIntervalId = setInterval(this.play, @updateInterval)

  stop: ->
    clearInterval(@playIntervalId)
    @playIntervalId = null

  play: =>
    console.log 'Playing..'

exports.WebPongJSGame = Game

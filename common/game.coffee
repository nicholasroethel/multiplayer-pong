exports = exports ? this

class Game
  constructor: ->
    @state =
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

exports.WebPongJSGame = Game

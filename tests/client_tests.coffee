Client = window.WebPongJSClient
Game = window.WebPongJSGame
conf = window.WebPongJSConfig

class MockCanvas
  constructor: ->
    @paths = []
    @rectangles = []
    @contexts = {
      '2d': this
    }
    @currentPath = null
    @clearRectCalled = false

  clearRect: ->
    @clearRectCalled = true

  getContext: (type) ->
    this

  fillRect: (x, y, h, w) ->
    @rectangles.push [x, y, h, w]

  beginPath: ->
    @currentPath = {}
    @paths.push @currentPath

  arc: (x, y, radius, angleStart, angleEnd, counterClockWise) ->
    @currentPath.arcs = @currentPath.arcs ? []
    @currentPath.arcs.push
      'x': x,
      'y': y,
      'radius': radius,
      'angleStart': angleStart,
      'angleEnd': angleEnd,
      'counterClockwise': counterClockWise

  fill: ->
    @currentPath.filled = true
    @currentpath = null

describe 'Client', ->
  it 'should be initialized', ->
    expect(window).to.be.ok()
    expect(Client).to.be.ok()
    expect(Game).to.be.ok()
    expect(conf).to.be.ok()
    canvas = new MockCanvas conf.board.size.x, conf.board.size.y
    game = new window.WebPongJSGame conf
    c = new Client conf, game, canvas

  it 'should draw the left block', ->
    canvas = new MockCanvas conf.board.size.x, conf.board.size.y
    game = new window.WebPongJSGame conf
    c = new Client conf, game, canvas
    c.drawLeftBlock 2

    expected=[[0, 2, conf.block.size.x, conf.block.size.y]]
    actual = canvas.rectangles

    expect(actual.length).to.be 1
    expect((_.difference actual[0], expected[0]).length).to.be 0

  it 'should draw the right block', ->
    canvas = new MockCanvas conf.board.size.x, conf.board.size.y
    game = new window.WebPongJSGame conf
    c = new Client conf, game, canvas
    c.drawRightBlock 13

    expected=[[conf.board.size.x - conf.block.size.x, 13, conf.block.size.x, conf.block.size.y]]
    actual = canvas.rectangles

    expect(actual.length).to.be 1
    expect((_.difference actual[0], expected[0]).length).to.be 0

  it 'should draw the ball', ->
    canvas = new MockCanvas conf.board.size.x, conf.board.size.y
    game = new window.WebPongJSGame conf
    c = new Client conf, game, canvas
    c.drawBall 3, 4
    expect(canvas.paths.length).to.be 1
    expect((_.last canvas.paths).arcs.length).to.be 1
    expect((_.last canvas.paths).arcs[0].x).to.be 3
    expect((_.last canvas.paths).arcs[0].y).to.be 4

    expect((_.last canvas.paths).arcs[0].radius).to.be conf.ball.radius
    expect((_.last canvas.paths).filled).to.be true

  it 'should draw the game state', ->
    canvas = new MockCanvas conf.board.size.x, conf.board.size.y
    game = new window.WebPongJSGame conf
    c = new Client conf, game, canvas
    c.drawState 'update', game.state
    expect(canvas.clearRectCalled).to.be true
    expect(canvas.paths.length).to.be 1
    expect((_.last canvas.paths).arcs.length).to.be 1
    expect((_.last canvas.paths).arcs[0].x).to.be game.state.ball.x
    expect((_.last canvas.paths).arcs[0].y).to.be game.state.ball.y

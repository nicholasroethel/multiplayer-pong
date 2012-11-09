if window?
  Client = window.WebPongJSClient
  Game = window.WebPongJSClientGame
  conf = window.WebPongJSConfig
  Message = window.WebPongJSMessage

  class MockBlock
    constructor: (@x, @y, @width, @height) ->


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

    closePath: ->

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

  class MockMessageBoard
  class MockScoreBoard

  class MockSocket
    constructor: ->
      @buffer = []

    send: (msg) ->
      @buffer.push msg

  describe 'Client', ->

    createClient = (cfg, game, canvas, messageBoard, scoreBoard) ->
      cfg = cfg ? conf
      game = game ? new Game cfg
      canvas = canvas ? new MockCanvas conf.board.size.x, conf.board.size.y
      messageBoard = messageBoard ? new MockMessageBoard
      scoreBoard = scoreBoard ? new MockScoreBoard
      new Client cfg, game, canvas, messageBoard, scoreBoard

    it 'should be initialized', ->
      expect(window).to.be.ok()
      expect(Client).to.be.ok()
      expect(Game).to.be.ok()
      expect(conf).to.be.ok()
      c = createClient()

    it 'should draw blocks', ->
      c = createClient()
      c.drawBlocks [new MockBlock 0, 2, 3, 4]

      expected = [[0, 2, 3, 4]]
      actual = c.board.rectangles

      expect(actual.length).to.be 1
      expect((_.difference actual[0], expected[0]).length).to.be 0

    it 'should draw the ball', ->
      c = createClient()
      c.drawBall 3, 4
      expect(c.board.paths.length).to.be 1
      expect((_.last c.board.paths).arcs.length).to.be 1
      expect((_.last c.board.paths).arcs[0].x).to.be 3
      expect((_.last c.board.paths).arcs[0].y).to.be 4

      expect((_.last c.board.paths).arcs[0].radius).to.be conf.ball.radius
      expect((_.last c.board.paths).filled).to.be true

    it 'should draw the game state', ->
      c = createClient()
      c.drawState 'update', c.game.state
      expect(c.board.clearRectCalled).to.be true
      expect(c.board.paths.length).to.be 3
      expect((_.first c.board.paths).arcs.length).to.be 1
      expect((_.first c.board.paths).arcs[0].x).to.be c.game.state.ball.x
      expect((_.first c.board.paths).arcs[0].y).to.be c.game.state.ball.y

    it 'keep score', ->
      c = createClient()
      c.game.state.score = [3, 4]
      c.onPoint 'point', c.game.state.score
      expect(c.scoreBoard.innerHTML).to.be "3 : 4"

    describe 'interaction with server', ->
      it 'should start connection with server', ->
        c = createClient()
        sock = new MockSocket
        c.start sock
        expect(c.sock).to.be sock
        expect(c.sock.onmessage).to.be.a 'function'
        expect(c.sock.onopen).to.be.a 'function'
        c.sock.onopen()
        expect(c.sock.buffer.length).to.be 1
        expect(c.sock.buffer[0]).to.be.a 'string'
        msg = Message.parse(c.sock.buffer[0])
        expect(msg.type).to.be 'init'
        expect(msg.data).to.be ''

    describe 'syncrhonization', ->
      it 'should buffer server updates', ->
        c = createClient()
        sock = new MockSocket
        c.start sock

        c.game.inputsBuffer = [{buffer: ['up'], index: 1}, {buffer: ['up'], index: 2}, {buffer: ['down'], index: 3}]
        c.onInit type: 'init', data: block: 'left'

        c.onUpdate type: 'update', data:
          state: c.game.state
          inputIndex: 0
        expect(c.game.inputsBuffer.length).to.be 3
        expect(c.game.serverUpdates.length).to.be 1

        c.onUpdate type: 'update', data:
          state: c.game.state
          inputIndex: 1
        expect(c.game.inputsBuffer.length).to.be 2
        expect(c.game.serverUpdates.length).to.be 2

        c.onUpdate type: 'update', data:
          state: c.game.state
          inputIndex: 2
        expect(c.game.serverUpdates.length).to.be 3
        oldUpdateCount = Game.SERVERUPDATES

        Game.SERVERUPDATES = 3
        c.onUpdate type: 'update', data:
          state: c.game.state
          inputIndex: 3
        expect(c.game.serverUpdates.length).to.be 3

        Game.SERVERUPDATES = oldUpdateCount
        expect(c.game.serverUpdates.length).to.be 3

      it 'should do linear interpolation', ->
        c = createClient()
        sock = new MockSocket
        c.start sock
        c.onInit type: 'init', data: block: 0
        expect(c.game.state.blocks.length).to.be 2

        prev =
          state: c.game.cloneState c.game.state
        next =
          state: c.game.cloneState c.game.state

        expect(prev.state.blocks.length).to.be 2
        expect(next.state.blocks.length).to.be 2

        now = (new Date).getTime()

        prev.state.lastUpdate = now - 200
        prev.state.blocks[0].y = 250
        prev.state.ball.x = 100
        prev.state.ball.y = 200

        next.state.lastUpdate = now + 200
        next.state.blocks[0] = _.clone prev.state.blocks[0]
        next.state.blocks[0].y = 400
        next.state.ball.x = 200
        next.state.ball.y = 300

        c.onUpdate {type: 'update', data: prev}
        c.onUpdate {type: 'update', data: next}

        c.game.state.blocks[0].y = 325

        c.game.interpolateState now

        expect(c.game.state.blocks[0].y).to.be 325
        expect(c.game.state.ball.x).to.be 150
        expect(c.game.state.ball.y).to.be 250

_ = require('underscore')
should = require('should')
game = require('../common/game')
config = require('../common/config').WebPongJSConfig

Ball = game.WebPongJSBall
Block = game.WebPongJSBlock
Game = game.WebPongJSServerGame

describe 'ServerGame', ->

  it 'should store configuration and initialize state', ->
    g = new Game config
    g.state.ball.should.be.an.instanceOf Ball
    g.state.blocks.length.should.equal 2
    g.state.blocks[0].should.be.an.instanceOf Block
    g.state.blocks[1].should.be.an.instanceOf Block
    should.strictEqual g.state.lastUpdate, null
    _.isEmpty(g.callbacks).should.equal true
    ('playIntervalId' of g).should.equal true
    should.strictEqual g.playIntervalId, null

  it 'should support loading state', ->
    g = new Game config
    newState = _.clone g.state
    newState.ball = new Ball 33, 33, 33
    g.update newState
    g.state.ball.x.should.equal 33

  it 'should vertically center the blocks', ->
    g = new Game config
    g.state.blocks[0].x.should.equal 0
    g.state.blocks[0].y.should.equal (config.board.size.y - config.block.size.y)/2
    g.state.blocks[1].x.should.equal config.board.size.x - config.block.size.x
    g.state.blocks[1].y.should.equal (config.board.size.y - config.block.size.y)/2

  it 'should add callbacks when subscribing', ->
    g = new Game config
    myCallback = (ev, data) -> 42
    g.on 'update', myCallback
    ('update' of g.callbacks).should.equal true
    g.callbacks['update'].length.should.equal 1
    g.callbacks['update'][0]('update', null).should.equal 42

  it 'should call the subscribed update callback', (done) ->
    cfg = _.clone config
    # Make the test run fast! Otherwise mocha complains.
    cfg.update.interval = 1
    g = new Game cfg
    oldLastUpdate = g.state.lastUpdate
    calledDone = false
    myCallback = (ev, newState) ->
      ev.should.equal 'update'
      newState.lastUpdate.should.be.above oldLastUpdate
      done()
      g.stop()
    g.on 'update', myCallback
    g.start()

  describe 'should do block collision check:', ->

    # it 'center within', ->
    #   ball = new Ball 0, 1, 3, 1, 1
    #   block = new Block 0, 1, 10, 20
    #   bounce = ball.blockPong(block)
    #   bounce.x.should.equal false
    #   bounce.y.should.equal false

    it 'left wall', ->
      ball = new Ball 17, 25, 3, 1, 1
      block = new Block 20, 20, 10, 10
      g = new Game config
      g.state.ball = ball
      bounce = g.blockPong(block)
      bounce.x.should.equal true
      bounce.y.should.equal false

    it 'right wall', ->
      ball = new Ball 28, 25, 3, -1, 1
      block = new Block 20, 20, 10, 10
      g = new Game config
      g.state.ball = ball
      bounce = g.blockPong(block)
      bounce.x.should.equal true
      bounce.y.should.equal false

    it 'bottom wall', ->
      ball = new Ball 28, 33, 3, 1, -1
      block = new Block 20, 20, 10, 10
      g = new Game config
      g.state.ball = ball
      bounce = g.blockPong(block)
      bounce.x.should.equal false
      bounce.y.should.equal true

    it 'top wall', ->
      ball = new Ball 28, 17, 3, 1, 1
      block = new Block 20, 20, 10, 10
      g = new Game config
      g.state.ball = ball
      bounce = g.blockPong(block)
      bounce.x.should.equal false
      bounce.y.should.equal true

    it 'x not within', ->
      ball = new Ball 16, 33, 3, 1, -1
      block = new Block 20, 20, 10, 10
      g = new Game config
      g.state.ball = ball
      bounce = g.blockPong(block)
      bounce.x.should.equal false
      bounce.y.should.equal false

    it 'y not within', ->
      ball = new Ball 28, 16, 3, -1, 1
      block = new Block 20, 20, 10, 10
      g = new Game config
      g.state.ball = ball
      bounce = g.blockPong(block)
      bounce.x.should.equal false
      bounce.y.should.equal false

  describe 'should do horizontal wall collision check:', ->

    it 'top', ->
      ball = new Ball 0, config.board.size.y - 3, 3, 0.3, 0.4
      g = new Game config
      g.state.ball = ball
      g.horizontalWallCollision().should.equal true

    it 'bottom', ->
      ball = new Ball 0, 2, 3, 0.3, 0.4
      g = new Game config
      g.state.ball = ball
      g.horizontalWallCollision().should.equal true

    it 'no collision', ->
      ball = new Ball 0, config.board.size.y - 3.01, 3, 0.3, 0.4
      g = new Game config
      g.state.ball = ball
      g.horizontalWallCollision().should.equal false

  describe 'vertical wall collision check', ->

    it 'left', ->
      ball = new Ball 0, 10, 3, 0.3, 0.4
      g = new Game config
      g.state.ball = ball
      g.checkForPoint().should.equal 1

    it 'right', ->
      ball = new Ball config.board.size.x, 3, 0.3, 0.4
      g = new Game config
      g.state.ball = ball
      g.checkForPoint().should.equal 0

    it 'ok', ->
      ball = new Ball 3.001, 16.999, 3, 0.3, 0.4
      g = new Game config
      g.state.ball = ball
      should.strictEqual g.checkForPoint(), null

describe 'Ball', ->

  it 'should store coordinates and velocity', ->
    ball = new Ball 0, 1, 3, 0.3, 0.4
    ball.x.should.equal 0
    ball.y.should.equal 1
    ball.radius.should.equal 3
    ball.xVelocity.should.equal 0.3
    ball.yVelocity.should.equal 0.4

  it 'should pong vertically', ->
    ball = new Ball 0, 10, 3, 0.3, 0.4
    ball.verticalPong()
    ball.yVelocity = - 0.4

  it 'should pong horizontally', ->
    ball = new Ball 0, 10, 3, 0.3, 0.4
    ball.horizontalPong()
    ball.xVelocity = - 0.3

describe 'Block', ->

  it 'should store its coordinates and size', ->
    block = new Block 0, 1, 10, 20
    block.x.should.equal 0
    block.y.should.equal 1
    block.width.should.equal 10
    block.height.should.equal 20

  it 'should calculate its borders', ->
    block = new Block 0, 1, 10, 20
    block.top().should.equal 1
    block.bottom().should.equal 21
    block.left().should.equal 0
    block.right().should.equal 10

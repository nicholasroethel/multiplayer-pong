_ = require('underscore')
should = require('should')
game = require('../common/game')
config = require('../common/config').WebPongJSConfig
utils = require('../common/utils')

Ball = game.WebPongJSBall
Block = game.WebPongJSBlock
Game = game.WebPongJSGame

describe 'Game', ->
  it 'should store configuration and initialize state', ->
    g = new Game config
    g.state.ball.should.be.an.instanceOf Ball
    g.state.blocks.left.should.be.an.instanceOf Block
    g.state.blocks.right.should.be.an.instanceOf Block
    should.strictEqual g.state.lastUpdate, null
    _.isEmpty(g.callbacks).should.equal true
    ('playIntervalId' of g).should.equal true
    should.strictEqual g.playIntervalId, null
  it 'should support loading state', ->
    g = new Game config
    newState = _.clone g.state
    g.update newState
    g.state.should.equal newState
  it 'should vertically center the blocks', ->
    g = new Game config
    g.state.blocks.left.x.should.equal 0
    g.state.blocks.left.y.should.equal (config.board.size.y - config.block.size.y)/2
    g.state.blocks.right.x.should.equal config.board.size.x - config.block.size.x
    g.state.blocks.right.y.should.equal (config.board.size.y - config.block.size.y)/2
  it 'should add callbacks when subscribing', ->
    g = new Game config
    myCallback = (ev, data) ->
      42
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
      if not calledDone
        ev.should.equal 'update'
        newState.lastUpdate.should.be.above oldLastUpdate
        done()
        # Avoid calling done() multiple times
        calledDone = true
    g.on 'update', myCallback
    g.start()

describe 'Ball', ->
  it 'should store coordinates and velocity', ->
    ball = new Ball 0, 1, 3, 0.3, 0.4
    ball.x.should.equal 0
    ball.y.should.equal 1
    ball.radius.should.equal 3
    ball.xVelocity.should.equal 0.3
    ball.yVelocity.should.equal 0.4

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
      bounce = ball.blockPong(block)
      bounce.x.should.equal true
      bounce.y.should.equal false
    it 'right wall', ->
      ball = new Ball 28, 25, 3, -1, 1
      block = new Block 20, 20, 10, 10
      bounce = ball.blockPong(block)
      bounce.x.should.equal true
      bounce.y.should.equal false
    it 'bottom wall', ->
      ball = new Ball 28, 33, 3, 1, -1
      block = new Block 20, 20, 10, 10
      bounce = ball.blockPong(block)
      bounce.x.should.equal false
      bounce.y.should.equal true
    it 'top wall', ->
      ball = new Ball 28, 17, 3, 1, 1
      block = new Block 20, 20, 10, 10
      bounce = ball.blockPong(block)
      bounce.x.should.equal false
      bounce.y.should.equal true
    it 'x not within', ->
      ball = new Ball 16, 33, 3, 1, -1
      block = new Block 20, 20, 10, 10
      bounce = ball.blockPong(block)
      bounce.x.should.equal false
      bounce.y.should.equal false
    it 'y not within', ->
      ball = new Ball 28, 16, 3, -1, 1
      block = new Block 20, 20, 10, 10
      bounce = ball.blockPong(block)
      bounce.x.should.equal false
      bounce.y.should.equal false

  describe 'should do horizontall wall collision check:', ->
    it 'top', ->
      ball = new Ball 0, 18, 3, 0.3, 0.4
      ball.horizontalWallCollision(20).should.equal true
    it 'bottom', ->
      ball = new Ball 0, 2, 3, 0.3, 0.4
      ball.horizontalWallCollision(20).should.equal true
    it 'no collision', ->
      ball = new Ball 0, 16.99, 3, 0.3, 0.4
      ball.horizontalWallCollision(20).should.equal false

  describe 'vertical wall collision check', ->
    it 'left', ->
      ball = new Ball 0, 10, 3, 0.3, 0.4
      ball.verticalWallCollision(20).should.equal true
    it 'right', ->
      ball = new Ball 0, 18, 3, 0.3, 0.4
      ball.verticalWallCollision(20).should.equal true
    it 'ok', ->
      ball = new Ball 3.001, 16.999, 3, 0.3, 0.4
      ball.verticalWallCollision(20).should.equal false

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
    block.borderUp().should.equal 1
    block.borderDown().should.equal 21
    block.borderLeft().should.equal 0
    block.borderRight().should.equal 10

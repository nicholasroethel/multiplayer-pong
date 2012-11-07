_ = require('underscore')
should = require('should')
config = require('../common/config').WebPongJSConfig
game = require('../common/game')
server = require('../server/pong-server')
utils = require('../common/utils')
message = require('../common/message')

Ball = game.WebPongJSBall
Block = game.WebPongJSBlock
Game = game.WebPongJSServerGame
Server = server.PongServer
Message = message.WebPongJSMessage

class MockConnection
  constructor: (@id) ->
    @buffer = []
    @callbacks = {}

  on: (ev, callback) ->
    @callbacks[ev] = callback

  write: (data) ->
    @buffer.push data
    console.log 'data: ', data

  testReadFromBuffer: ->
    Message.parse @buffer.pop()
  
  testSendToServer: (msgType, data) ->
    msg = new Message msgType, data
    @callbacks['data'](msg.stringify())

class MockHttpServer
  constructor: ->
    @handlers = {}
    @callbacks = {}
    @listening = null

  installHandler: (prefix, handler) ->
    @handlers[prefix] = handler

  on: (ev, callback) ->
    @callbacks[ev] = callback

  listen: (port, addr) ->
    @listening = {port: port, addr: addr}

class MockSockJsServer
  constructor: ->
    @callbacks = {}

  installHandlers: (httpServer, opts) ->
    httpServer.installHandler opts.prefix, this.handle

  handle: =>

  on: (ev, callback) ->
    @callbacks[ev] = callback

describe 'Server', ->
  it 'should store configuration and initialize state', ->
    s = new Server
    (s.config?).should.equal true
    s.config.should.equal config
    (s.game?).should.equal true
    (_.difference s.availableBlocks, ['left', 'right']).length.should.equal 0

  it 'should listen', ->
    s = new Server
    sockServer = new MockSockJsServer
    httpServer = new MockHttpServer
    s.sockServer = sockServer
    s.httpServer = httpServer
    s.listen()
    (httpServer.listening?).should.equal true
    (httpServer.handlers[config.server.prefix]?).should.equal true
    (sockServer.callbacks['connection']?).should.equal true

  it 'should handle new connections', ->
    s = new Server
    sockServer = new MockSockJsServer
    httpServer = new MockHttpServer
    s.sockServer = sockServer
    s.httpServer = httpServer
    s.listen()
    
    conn = new MockConnection 'conn1'
    sockServer.callbacks['connection'](conn)

    (conn.callbacks['data']?).should.equal true

    s.playerCount().should.equal 1
    s.players[conn.id].inputIndex.should.equal -1

  it 'should handle closing of connections', ->
    s = new Server
    sockServer = new MockSockJsServer
    httpServer = new MockHttpServer
    s.sockServer = sockServer
    s.httpServer = httpServer
    s.listen()
    
    conn = new MockConnection 'conn1'
    sockServer.callbacks['connection'](conn)

    conn.callbacks['close'](conn)
    (_.isEmpty s.players).should.equal true

  it 'should handle "init" message from client', ->
    s = new Server
    sockServer = new MockSockJsServer
    httpServer = new MockHttpServer
    s.sockServer = sockServer
    s.httpServer = httpServer
    s.listen()
    
    conn = new MockConnection 'conn1'
    sockServer.callbacks['connection'](conn)

    conn.testSendToServer 'init', null
    resp = conn.testReadFromBuffer()
    resp.type.should.equal 'init'
    resp.data.block.should.equal 'right'

  it 'should save input updates from clients', ->
    s = new Server
    sockServer = new MockSockJsServer
    httpServer = new MockHttpServer
    s.sockServer = sockServer
    s.httpServer = httpServer
    s.listen()
    
    conn = new MockConnection 'conn1'
    sockServer.callbacks['connection'](conn)

    conn.testSendToServer 'init', null
    resp = conn.testReadFromBuffer()
    block = resp.data.block

    conn.testSendToServer 'input', {buffer: ['up', 'up'], index: 0}
    conn.testSendToServer 'input', {buffer: ['up', 'down'], index: 1}
    s.game.inputUpdates[block].updates.length.should.equal 2

    s.game.processInputs()

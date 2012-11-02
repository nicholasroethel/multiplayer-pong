exports = window

Message = exports.WebPongJSMessage

class Client

  constructor: (@conf, @game) ->
    @sock = null
    @initialDrift = null
    @board = document.getElementById(@conf.board.id)
    @context = @board.getContext('2d')

  start: ->

    yBlock = @board.height / 2 - @conf.block.size.y / 2
    @game.setLeftBlockPosition yBlock
    @game.setRightBlockPosition yBlock
    @game.setBallPosition 0, 0

    @sock = new SockJS "http://#{@conf.server.addr}:#{@conf.server.port}#{@conf.server.prefix}"

    @sock.onmessage = (e) =>
      msg = Message.parse(e.data)

      switch msg.type
        when 'init'
          @initialDrift = Math.abs(Number(msg.data) - (new Date).getTime())
        when 'tick'
          if @game.state.lastUpdate?
            @diff = @game.state.lastUpdate - msg.data - @initialDrift
            if @diff > @conf.update.maxDrift
              payload = new Message 'update'
              @sock.send payload.stringify()
        when 'update'
          @game.update msg.data
        else
          console.log msg.type

    @sock.onopen = =>
      payload = new Message 'init'
      @sock.send payload.stringify()
      @game.start this.drawState

    @sock.onclose = =>
      console.log 'Connection closed'
      @game.stop()

  drawLeftBlock: (y) ->
    @context.fillRect 0, y, @conf.block.size.x, @conf.block.size.y

  drawRightBlock: (y) ->
    @context.fillRect @conf.board.size.x - @conf.block.size.x, y,
      @conf.block.size.x, @conf.block.size.y

  drawBall: (x, y) ->
    @context.beginPath()
    @context.arc x, y, @conf.ball.radius, 0, 2 * Math.PI, false
    @context.fillStyle = 'black'
    @context.fill()

  drawState: (state) =>
    @context.clearRect 0, 0, @board.width, @board.height
    this.drawBall state.ball.position.x, state.ball.position.y
    this.drawLeftBlock state.blocks.left.y
    this.drawRightBlock state.blocks.right.y

exports.WebPongJSClient = Client

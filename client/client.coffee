exports = window

Message = exports.WebPongJSMessage

class Client

  @KEYS:
    up: 38
    down: 40

  constructor: (@conf, @game, @board) ->
    @sock = null
    @initialDrift = null
    @context = @board.getContext '2d'
    @controlledBlock = null

  start: (@sock) ->
    @sock = @sock ? new SockJS "http://#{@conf.server.addr}:#{@conf.server.port}#{@conf.server.prefix}"
    @sock.onmessage = (e) =>
      msg = Message.parse(e.data)

      switch msg.type
        when 'init'
          @initialDrift = Number(msg.data.timestamp) - (new Date).getTime()
          @game.on 'update', this.drawState
          @game.on 'game over', this.gameOver
          @game.start @initialDrift

          if msg.data.block == 'left'
            @controlledBlock = @game.state.blocks.left
          else
            @controlledBlock = @game.state.blocks.right

          document.onkeydown = this.onKeyDown
          document.onkeyup = this.onKeyUp

        when 'tick'
          payload = new Message 'update'
          @sock.send payload.stringify()
        when 'update'
          #@game.update msg.data
        else
          console.log msg.type

    @sock.onopen = =>
      payload = new Message 'init'
      @sock.send payload.stringify()

    @sock.onclose = =>
      console.log 'Connection closed'
      @game.stop()

  onKeyDown: (ev) =>
    @sock.send (new Message 'moveDown', '')
    switch ev.keyCode
      when Client.KEYS.up
        @controlledBlock.movingUp = true
      when Client.KEYS.down
        @controlledBlock.movingDown = true

  onKeyUp: (ev) =>
    @sock.send (new Message 'moveUp', '')
    switch ev.keyCode
      when Client.KEYS.up
        @controlledBlock.movingUp = false
      when Client.KEYS.down
        @controlledBlock.movingDown = false

  drawLeftBlock: (y) ->
    @context.beginPath()
    @context.fillStyle = @conf.block.left.color
    @context.fillRect 0, y, @conf.block.size.x, @conf.block.size.y
    @context.closePath()
    @context.fill()

  drawRightBlock: (y) ->
    @context.beginPath()
    @context.fillStyle = @conf.block.right.color
    @context.fillRect @conf.board.size.x - @conf.block.size.x, y,
      @conf.block.size.x, @conf.block.size.y
    @context.closePath()
    @context.fill()

  drawBall: (x, y) ->
    @context.beginPath()
    @context.fillStyle = @conf.ball.color
    @context.arc x, y, @conf.ball.radius, 0, 2 * Math.PI, false
    @context.closePath()
    @context.fill()

  drawState: (ev, state) =>
    @context.clearRect 0, 0, @board.width, @board.height
    this.drawBall state.ball.x, state.ball.y
    this.drawLeftBlock state.blocks.left.y
    this.drawRightBlock state.blocks.right.y

  gameOver: (ev, data) =>
    # Temp placeholder
    window.alert 'Game over!'

exports.WebPongJSClient = Client

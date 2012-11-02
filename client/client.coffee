exports = window

Message = exports.WebPongJSMessage

class Client

  constructor: (@conf, @game) ->
    @sock = null
    @initialDrift = null

  start: ->
    @sock = new SockJS "http://#{@conf.server.addr}:#{@conf.server.port}#{@conf.server.prefix}"

    @sock.onmessage = (e) =>
      msg = Message.parse(e.data)

      switch msg.type
        when 'init'
          @initialDrift = Math.abs(Number(msg.data) - (new Date).getTime())
        when 'tick'
          console.log 'ticked!'
          if @game.state.lastUpdate?
            @diff = @game.state.lastUpdate - msg.data - @initialDrift
            console.log "Drift #{@diff}"
            if @diff > @conf.update.maxDrift
              console.log 'Want update'
              payload = new Message 'update'
              @sock.send payload.stringify()
        when 'update'
          @game.update msg.data
        else
          console.log msg.type

    @sock.onopen = =>
      payload = new Message 'init'
      @sock.send payload.stringify
      @game.start()

    @sock.onclose = =>
      console.log 'Connection closed'
      @game.stop()

exports.WebPongJSClient = Client

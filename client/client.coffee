exports = window

class Client

  constructor: (@conf, @game) ->
    @sock = null
    @initialDrift = null

  start: ->
    @sock = new SockJS "http://#{@conf.server.addr}:#{@conf.server.port}#{@conf.server.prefix}"

    @sock.onmessage = (e) =>
      msg = JSON.parse(e.data)

      switch msg.type
        when 'init'
          @initialDrift = Math.abs(Number(msg.data) - (new Date).getTime())
        when 'tick'
          console.log 'ticked!'
        else
          console.log msg.type

      console.log '[message]', @initialDrift
      if @initialDrift > @conf.update.maxDrift
        console.log 'Want update'
        @sock.send JSON.stringify type: 'update', data: ''

    @sock.onopen = =>
      @sock.send JSON.stringify type: 'init', data: ''
      @game.start()

    @sock.onclose = =>
      console.log 'Connection closed'
      @game.stop()

exports.WebPongJSClient = Client

exports = window

Game = window.WebPongJSGame

class Client

  constructor: (@conf) ->
    @game = new Game
    @sock = new SockJS "http://#{@conf.server.addr}:#{@conf.server.port}#{@conf.server.prefix}"

  start: ->
    @sock.onmessage = (e) =>
      drift = Math.abs(Number(e.data) - (new Date).getTime())
      console.log '[message]', drift
      if drift > @conf.update.maxDrift
        console.log 'Want update'
        @sock.send 'update'

    @sock.onopen = =>
      @game.start()
      console.log 'Connected, sending hi'
      @sock.send 'Hi, dude!'
      @sock.send 'Hi again, dude!'

    @sock.onclose = =>
      console.log 'Connection closed'
      @game.stop()

exports.WebPongJSClient = Client

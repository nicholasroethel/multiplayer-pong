# This is currently an echo server

sockjs = require 'sockjs'
http = require 'http'

pongConfig = {
    listen:
        addr: '0.0.0.0',
        port: 8089,
    prefix:
        pong: '/pong',
    update:
        interval: 100, # milliseconds
}

gameState = {
    ball:
        position: x: 0, y: 0
}

internalState = {
    intervalUpdaterId: null,
}

sockServer = sockjs.createServer()
sockServer.on 'connection', (conn) ->
    conn.on 'data', (message) ->
        echoedMsg = "Echoed '#{message}'"
        conn.write echoedMsg
        console.log "Sending back '#{echoedMsg}'"
    conn.on 'close', ->
        console.log 'Connection closed'
        if internalState.intervalUpdaterId?
            console.log('Stopping interval updater ...')
            clearInterval(internalState.intervalUpdaterId)
            internalState.intervalUpdaterId = null
            console.log('Stopped interval updater.')
    # A periodic updater callback that sends the game state to the 
    # clients in order to keep them syncrhnozied
    broadcastState = ->
        console.log('State update ...')
    internalState.intervalUpdaterId = setInterval broadcastState, pongConfig.update.interval

server = http.createServer()
sockServer.installHandlers server, prefix: pongConfig.prefix.pong
server.listen(pongConfig.listen.port, pongConfig.listen.addr)

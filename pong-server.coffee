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
    blocks:
        left:
            height: 0
        right:
            height: 0

}

internalState = {
    intervalUpdaterId: null,
    clientConnections: {},
}

# Utility function to check wheter an object (dict) is "empty"
isEmpty = (d) ->
    return Object.keys(d).length == 0

sockServer = sockjs.createServer()
sockServer.on 'connection', (conn) ->
    # Add the new connection to the client connection "set"
    internalState.clientConnections[conn] = null

    conn.on 'data', (message) ->
        echoedMsg = "Echoed '#{message}'"
        conn.write echoedMsg
        console.log "Sending back '#{echoedMsg}'"

    conn.on 'close', ->
        console.log 'Connection closed'
        delete internalState.clientConnections[conn]
        if isEmpty(internalState.clientConnections) and internalState.intervalUpdaterId?
            console.log 'Stopping interval updater ...'
            clearInterval internalState.intervalUpdaterId
            internalState.intervalUpdaterId = null
            console.log 'Stopped interval updater.'

    # The callback that will be called periodically to send the game state to
    # the clients in order to keep them syncrhnozied.
    broadcastState = ->
        console.log 'State update ...'
    internalState.intervalUpdaterId = setInterval broadcastState, pongConfig.update.interval

server = http.createServer()
sockServer.installHandlers server, prefix: pongConfig.prefix.pong
server.listen(pongConfig.listen.port, pongConfig.listen.addr)

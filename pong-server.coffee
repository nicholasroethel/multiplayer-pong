# This is currently an echo server

sockjs = require 'sockjs'
http = require 'http'

config = {
    listen: {
        addr: '0.0.0.0',
        port: 8089,
    },
    prefix: {
        pong: '/pong',
    },
    update: {
        interval: 5,
    }
}

sockServer = sockjs.createServer()
sockServer.on 'connection', (conn) ->
    conn.on 'data', (message) ->
        echoedMsg = "Echoed '#{message}'"
        conn.write echoedMsg
        console.log "Sending back '#{echoedMsg}'"
    conn.on 'close', ->

server = http.createServer()
sockServer.installHandlers server, prefix: config.prefix.pong
server.listen(config.listen.port, config.listen.addr)

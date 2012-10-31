# This is currently an echo server

sockjs = require 'sockjs'
http = require 'http'

ADDR='0.0.0.0'
PORT=8089
PONG_PREFIX = '/pong'

sockServer = sockjs.createServer()
sockServer.on 'connection', (conn) ->
    conn.on 'data', (message) ->
        conn.write message
    conn.on 'close', () ->

server = http.createServer()
sockServer.installHandlers server, { prefix: PONG_PREFIX }
server.listen(PORT, ADDR)

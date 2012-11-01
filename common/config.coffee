exports = exports ? this

exports.WebPongJSConfig =
  server:
    addr: '0.0.0.0',
    port: 8089,
    prefix: '/pong',
  update:
    interval: 1000, # milliseconds

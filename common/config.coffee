exports = exports ? this

exports.WebPongJSConfig =
  server:
    addr: '0.0.0.0',
    port: 8089,
    prefix: '/pong',
  update:
    # milliseconds
    interval: 40,   # Game update intervals
    syncTime: 200,  # Server sync period
    maxDrift: 200,  # Maximum drift for each client
  board:
    id: 'board'
    size:
      x: 600, y: 400
  block:
    size:
      x: 25, y: 100
  ball:
    radius: 15

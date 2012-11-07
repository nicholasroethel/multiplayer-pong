exports = exports ? this

exports.WebPongJSConfig =
  server:
    addr: '0.0.0.0',
    port: 8089,
    prefix: '/pong',
  client:
    interpLatency: 120, # interpolation latency interval
  update:
    # milliseconds
    interval: 25,   # Game update intervals, ms.
    syncTime: 50, # Server sync period
    maxDrift: 100,  # Maximum drift for each client
  board:
    id: 'board'
    size:
      x: 600, y: 400
  block:
    size:
      x: 8, y: 100
    left: color: 'blue'
    right: color: 'red'
    velocity: 0.5
  ball:
    radius: 8
    xVelocity: 0.2
    yVelocity: 0.4
    color: 'black'
  messageBoard:
    id: 'message_board'

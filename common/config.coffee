exports = exports ? this

# All of these settings require restart of the server, except for the ones
# under "client".

exports.WebPongJSConfig =
  # demoMode means no points; ball bounces off all walls.
  demoMode: true
  server:
    addr: '0.0.0.0'
    port: 8089
    prefix: '/pong'
  client:
    interpolate: true # interpolate or use naive approach
    interpLatency: 100 # interpolation latency interval
  update:
    # milliseconds
    interval: 20 # Game update intervals, ms.
    syncTime: 40 # Server sync period. Must be low when using interpolation.
    maxDrift: 100 # Maximum drift for each client
    timerAccuracy: 5
  board:
    id: 'board'
    size:
      x: 600, y: 400
  block:
    size:
      x: 8, y: 100
    colors: ['blue', 'red']
    names: ['left', 'right']
    velocity: 0.08
  ball:
    radius: 8
    xVelocity: 0.3
    yVelocity: 0.4
    color: 'black'
    accelerationFromPaddle: 0.05
  messageBoard:
    id: 'message_board'
  scoreBoard:
    id: 'score_board'

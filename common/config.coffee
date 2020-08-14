exports = exports ? this

# All of these settings require restart of the server, except for the ones
# under "client".

config =
  # demoMode means no points; ball bounces off all walls.
  demoMode: true
  server:
    addr: '0.0.0.0'
    port: process.env.port || 8089
    prefix: '/pong'
  client:
    interpolate: false
    regularLinearInterpolate: false 
    optimizedLinearInterpolate: false
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
      x: 500, y: 300
  block:
    size:
      x: 8, y: 100
    colors: ['blue', 'red']
    names: ['left', 'right']
    velocity: 0.08
  ball:
    radius: 6
    xVelocity: 0.4
    yVelocity: 0.15
    color: 'black'
    accelerationFromPaddle: 0.05
  messageBoard:
    id: 'message_board'
  scoreBoard:
    id: 'score_board'

config.client.maxInterp = config.ball.radius * 5

exports.WebPongJSConfig = config

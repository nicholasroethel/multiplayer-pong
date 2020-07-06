Multiplayer Pong
=========

This is a very basic implementation of the original pong game written in coffeescript,
NodeJS and SockJS. 

The 2 clients rely on the server for state synchronization, and the way the states 
are synced can be changed within the config file. 

The user can pick the basic naive approach (no interpolation between states), a basic
linear interpolation approach, or a more advanced and more optimized approach that 
works for the edge case where exactly 1 interval has passed. 

Both interpolation methods have the ability to predict input and create a smooth
synchronization between the clients and the server. 

Note: this repo was originally forked from: https://github.com/emou/webpongjs,
but has been modified to better demonstrate the various ways of dealing with
gamestate and lag compensation. 

Run
----------

How to run the game:

1. `git clone https://github.com/nicholasroethel/multiplayer-pong.git`
2. `cd multiplayer-pong`
3. `make install-modules` if it's your first time running
4. `make compile` or `make wcompile` to autocompile changes
5. `make run-server`
6. Open `./client/pong-client.html` in at least 2 browser tabs

Config File
-----------

Most of the parameters in the project can be configured by editing the
`common/config.coffee` file.

By default `demoMode` is `true`, which means that there are no points and the
ball just bounces off of vertical walls, too. This is useful for illustrating
the synchronization without having to move blocks in 2 browsers.

### Config Settings for the Naive Approach (No Interpolation) 
    interpolate: false
    regularLinearInterpolate: false
    optimizedLinearInterpolate: false

### Config Settings for Basic Linear Interpolation 
    interpolate: true
    regularLinearInterpolate: true
    optimizedLinearInterpolate: false

### Config Settings for Optimized Linear Interpolation
    interpolate: true
    regularLinearInterpolate: false
    optimizedLinearInterpolate: true

### Playing Around With Latency

When using either the basic or optimized linear interpolation approaches, one has the ability to change
the latency that has been introduced to the game. This can be used to see how the interpolation effects
different latencties. 

Note: please see the known issues section (below) for guidelines

Known Issues
------------

1. Setting the interpolation latency to be very low causes the game to break (i.e. 0 or 1 don't work
and we wouldn't reccomend going below 30ms). Also latencies over 500 have not been tested
2. Setting the ball speed to be really high breaks the game

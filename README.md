webpongjs
=========

This is a simple pong demo using coffeescript, Node.js and sockjs. The pong
game is synchronized by the server for the 2 clients.

The interesting part in it is that it uses linear interpolation and input
prediction for smoother synchronization of the clients with the server.

See also Known Issues

Run
----------


Here's how I run it

1. `git clone https://github.com/emou/webpongjs.git`
2. `cd webpongjs`
3. `make install-modules` (first run only)
4. `make compile` (`make wcompile` if you'll be making changes)
5. `make run-server`
6. Open `./client/pong-client.html` in 2 browsers

NOTE: Only tested in the following browsers: Firefox 16, Chrome 23 and Safari 5.1.6.

Config File
-----------

Most of the parameters in the project can be configured by editing the
`common/config.coffee` file.

By default `demoMode` is `true`, which means that there are no
points and the ball just bounces off of vertical walls, too.

You can turn of interpolation by setting `client.interpolate` to `false`.

Known Issues
------------

1. It is not recommended to make arbitrary changes to the config file such as
   trying to make the blocks too wide, the ball too fast and/or the ball too
   big :) The collision detection and bouncing will break.

2. When doing interpolation, the "bouncing ball problem" is not solved, i.e. it is common
   for you to not see the ball hitting the wall:

         x      |
           o    |
             x  |
               o|
             x  |
           o    |
         x      |

   Instead you could see something like this when interpolating based only on the
   updates marked with 'x'

         x     |
           o   |
            x  |
            o  |
            x  |
           o   |
         x     |


3. There is no timeout between points, i.e. the ball is immediately reset to
   the starting position and the game is restarted.  As it's not trivial to
   syncrhonize the timeout, I've ignored it for the moment.

4. One game per server.

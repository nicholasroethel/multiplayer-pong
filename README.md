webpongjs
=========

*Currently, this is work-in-progress in very early stages*

This is a small experiment using Node.js and sockjs to implement pong game
with 2 clients.

1. git clone https://github.com/emou/webpongjs.git 
2. `cd webpongjs`
3. `make fast-run`
4. Open `./client/pong-client.html` in 2 browsers


Known issues
------------

- Uses a naive approach for synchronization: we periodically update our
  position based on the authorative position given by the server. This results
  in choppy movement. It can be solved by running the game on each client in the past
  and buffering server updates (including updates for the "future"). Then at each
  client update we can interpolate between the server positions in which the client time
  falls between to get smooth transition. Adding input prediction, so we
  immediately act on local input and use only inputs unprocessed by the server
  for each position prediction makes this more complex.

- No scoring, single game per server. This is not hard to fix.

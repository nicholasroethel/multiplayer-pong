# A shared module for the game logic,
# used by both client and server:
# - it is require()d by the server
# - it is compiled (see ../Makefile) to javascript and included in the client
root = exports ? this
root.WebPongJSGame =
    foo: 3

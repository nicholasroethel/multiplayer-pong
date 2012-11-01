COFFEE=coffee
COFFEE_TO_COMPILE=common/*.coffee
CCOMPILE=--compile $(COFFEE_TO_COMPILE)
SERVER=server/pong-server.coffee

run-server:
	$(COFFEE) $(SERVER)

compile:
	$(COFFEE) $(CCOMPILE)

wcompile:
	$(COFFEE) --watch $(CCOMPILE)

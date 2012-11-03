COFFEE=coffee
COFFEE_TO_COMPILE=common/*.coffee client/*.coffee
CCOMPILE=--compile $(COFFEE_TO_COMPILE)
SERVER=server/pong-server.coffee
DEPS=underscore mocha should sockjs

MOCHA=mocha
TESTS=./tests/*.coffee

run-server:
	$(COFFEE) $(SERVER)

install-modules:
	# Installs node.js module dependencies
	sudo npm install -g $(DEPS)

compile:
	$(COFFEE) $(CCOMPILE)

wcompile:
	$(COFFEE) --watch $(CCOMPILE)

test:
	$(MOCHA) --reporter list --compilers coffee:coffee-script --watch $(TESTS)

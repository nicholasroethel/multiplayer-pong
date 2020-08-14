COFFEE=./node_modules/coffee-script/bin/coffee
COFFEE_TO_COMPILE=common/*.coffee client/*.coffee tests/*.coffee server/*.coffee
CCOMPILE=--compile $(COFFEE_TO_COMPILE)
SERVER=server/pong-server.coffee

MOCHA=./node_modules/mocha/bin/mocha
TESTS=./tests/*.coffee

run-server:
	$(COFFEE) $(SERVER)

install-modules:
	# Installs dependencies
	npm install

compile:
	$(COFFEE) $(CCOMPILE)

wcompile:
	$(COFFEE) --watch $(CCOMPILE)

fast-run: install-modules compile run-server

open: 
	open client/pong-client.html

test:
	$(MOCHA) --reporter list --compilers coffee:coffee-script --watch $(TESTS)

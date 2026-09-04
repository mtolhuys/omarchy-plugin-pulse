.DEFAULT_GOAL := help

.PHONY: help test validate update install dev-install

help:
	@printf '%s\n' \
		'Omarchy Plugin Pulse development commands:' \
		'  make test         Run helper unit checks' \
		'  make validate     Test and validate the Omarchy plugin manifest' \
		'  make update       Install the exact current working tree locally'

test:
	PULSE_ROOT="$$(pwd)" ./bin/test

validate: test
	omarchy plugin validate .

update: dev-install
install: dev-install

dev-install:
	omarchy plugin add "$$(pwd)" --enable --force 2>/dev/null || omarchy plugin update io.github.mtolhuys.plugin-pulse

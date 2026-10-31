# Settings from ./configure; the defaults below apply without it.
-include config.mk

TCLSH   ?= tclsh9.0
VENV    ?= .venv
PREFIX  ?= /usr/local
LIBDIR  ?= $(PREFIX)/lib
VERSION ?= $(shell sed -n 's/.*package ifneeded zmq \([0-9.]*\).*/\1/p' lib/zmq/pkgIndex.tcl)
PKGDIR   = $(DESTDIR)$(LIBDIR)/zmq$(VERSION)

.PHONY: test test-tcp venv install uninstall

# Extra tcltest options, e.g. make test TESTFLAGS="-file zmtp.test -verbose bpe"
test:
	$(TCLSH) tests/all.tcl $(TESTFLAGS)

# Also run tests that need the tcp transport (bind/connect).
test-tcp:
	$(TCLSH) tests/all.tcl -constraints tcpTransport $(TESTFLAGS)

install:
	install -d $(PKGDIR)
	install -m 644 lib/zmq/*.tcl $(PKGDIR)

uninstall:
	rm -rf $(PKGDIR)

# Python venv with pyzmq for the libzmq interop tests.
venv: $(VENV)/bin/python3

$(VENV)/bin/python3:
	uv venv $(VENV)
	uv pip install --python $(VENV)/bin/python3 pyzmq

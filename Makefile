TCLSH ?= tclsh9.0
VENV  ?= .venv

.PHONY: test test-tcp venv

# Extra tcltest options, e.g. make test TESTFLAGS="-file zmtp.test -verbose bpe"
test:
	$(TCLSH) tests/all.tcl $(TESTFLAGS)

# Also run tests that need the tcp transport (bind/connect).
test-tcp:
	$(TCLSH) tests/all.tcl -constraints tcpTransport $(TESTFLAGS)

# Python venv with pyzmq for the libzmq interop tests.
venv: $(VENV)/bin/python3

$(VENV)/bin/python3:
	uv venv $(VENV)
	uv pip install --python $(VENV)/bin/python3 pyzmq

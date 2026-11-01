# tclzmq

Pure Tcl implementation of ZeroMQ (ZMTP 3.1). Its API mirrors the libzmq C API.
It is meant to give a Tcl Jupyter kernel ZeroMQ support without a compiled extension.

## API mapping

| C                                   | Tcl                                   |
|-------------------------------------|---------------------------------------|
| `zmq_ctx_new()`                     | `zmq::ctx_new`                        |
| `zmq_socket(ctx, ZMQ_ROUTER)`       | `zmq::socket $ctx ZMQ_ROUTER`         |
| `zmq_setsockopt(s, opt, &v, len)`   | `zmq::setsockopt $s ZMQ_LINGER 0`     |
| `zmq_send(s, buf, len, flags)`      | `zmq::send $s $bytes ZMQ_SNDMORE`     |
| `zmq_recv(s, buf, len, flags)`      | `set bytes [zmq::recv $s ?flags?]`    |
| `zmq_msg_t` / `zmq_msg_init(&m)`    | `set m [zmq::msg_init]`               |
| return -1 + `errno`                 | Tcl error, `errorCode {ZMQ EAGAIN}`   |

Options, socket types and flags can be given as integers or constant names.
You can also call everything through the `zmq` ensemble, e.g. `zmq socket $ctx ZMQ_REQ`.
Data is handled as byte strings. Convert text with `encoding convertto utf-8` before sending it;
pass binary bytearrays (for example, values from `binary format`) directly, without text encoding.

## Layout

- `lib/zmq/`: the package (`package require zmq`)
  - `zmtp.tcl`: wire codec (greeting, frames, commands, metadata)
  - `context.tcl`, `socket.tcl`, `msg.tcl`: the public API
  - `z85.tcl`, `constants.tcl`, `error.tcl`
- `tests/`: tcltest suite. `interop.test` checks behaviour against libzmq through pyzmq.

## Installing

```sh
./configure --prefix=/usr/local     # optional: --libdir=DIR, --with-tclsh=PATH
make install                        # installs to $libdir/zmq<version>; honours DESTDIR
make uninstall
```

Without `./configure`, the default prefix is `/usr/local`. Make sure the install directory is
on `auto_path` (or `TCLLIBPATH`).

## Testing

```sh
make test                                   # uses tclsh9.0 by default
make test TCLSH=tclsh8.6
make test TESTFLAGS="-file zmtp.test -verbose bpe"
make venv                                   # .venv with pyzmq (uses uv)
make test-tcp                               # also run tests needing bind/connect
```

The interop tests need pyzmq. Run `make venv` to set it up. Tests that need the tcp
transport only run with `make test-tcp`.

See [doc/API.md](doc/API.md) for the full API reference and [TODO.md](TODO.md) for the roadmap.

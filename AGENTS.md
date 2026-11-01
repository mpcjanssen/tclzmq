# Notes for coding agents (tclzmq)

Pure Tcl implementation of ZeroMQ (ZMTP 3.1) with a libzmq-style API. It provides ZeroMQ for a
Tcl Jupyter kernel (the kernel lives in a separate repo, `../tcljupyter`).

## Layout

| File | Contents |
|---|---|
| `lib/zmq/zmq.tcl` | Package entry: sources all files, `zmq` ensemble, `version`, `has` |
| `lib/zmq/constants.tcl` | zmq.h constants, `ConstName`/`ToInt` (name normalisation) |
| `lib/zmq/error.tcl` | `Fail code ?message?`, `errno`, `strerror` |
| `lib/zmq/context.tcl` | `ctx_*` |
| `lib/zmq/socket.tcl` | Socket API, options, endpoints, `send`/`recv`/`*_multipart`, `poll`, `readable` |
| `lib/zmq/engine.tcl` | Connection engine (`Attach`, `Detach`, ZMTP state machine), `Wait`/`Notify`, generic routing, `Events` |
| `lib/zmq/routing.tcl` | Per-type routing: ROUTER, PUB/SUB/XPUB/XSUB (hooks `PipeReady`, `PipeGone`, `RouteIncoming`, `RouterSend`, `FanoutSend`) |
| `lib/zmq/tcp.tcl` | tcp bind/accept (`TcpBind`, `TcpAccept`) |
| `lib/zmq/zmtp.tcl` | Pure wire codec, no I/O (`zmq::zmtp::*`) |
| `lib/zmq/msg.tcl`, `z85.tcl` | `msg_*`, Z85 |
| `doc/API.md` | Public API reference: **keep in sync** |
| `TODO.md` | Roadmap per phase: **tick items when done** |

## Conventions

- **Naming.**
  - C `zmq_foo` maps to `zmq::foo`.
  - Public commands are lowercase and exported via the ensemble. Internal procs are Capitalized
    and not exported.
  - Tcl-only extensions (`recv_multipart`, `send_multipart`, `readable`, `const`) are marked as
    such in `doc/API.md`.
- **Errors.** Raise them with `Fail ERRNO ?message?`. It uses `return -level 2`, so the error
  comes from the *caller*; it works from helper procs too. The errorCode is `{ZMQ ERRNO}`. Give a
  specific message when the generic `strerror` text would be unhelpful (bad handle, bad
  constant, non-byte data).
- **Constants.** They accept ints, `ZMQ_FOO`, `FOO`, `foo` or `-foo`, and lists of these are
  OR-ed together.
- **Data.** Data is bytes: characters above `\xff` are rejected (`CheckBytes`). Characters in
  `\x80`-`\xff` are *not* detected and go out as Latin-1, so callers must always use
  `encoding convertto utf-8`.
- **Name shadowing.** Inside `::zmq`, `socket` and `close` are the zmq commands. Use `::socket`
  and `::close` for Tcl channels.
- **Tcl version.** Target Tcl 8.6+. Do not use 8.7/9-only commands (`dict getdef`, `lpop`,
  `lseq`, ...). Tests run on `tclsh9.0`.
- **Comments.** Keep them to one short line, and only for things the code cannot show.
- **Commits.** Do not add a `Co-authored-by: Copilot` trailer (or any other co-author line) to
  commit messages in this repo. Stage only the files the task changed, and push only when asked.

## Architecture lessons

- **Connections.** Each connection is a `conns($id)` dict holding the socket, channels, state
  (`greeting`, then `handshake`, then `ready`), the input buffer, the partial message, props,
  `routingId` and `subs`.
- **Handshake.** We send the full 64-byte greeting at once, then READY after the peer's greeting
  arrives. Only the NULL mechanism is supported.
- **Input parsing.** Input is parsed at an offset (`zmtp::parse_frame buf ?offset?`) and the
  buffer is trimmed once per read (`ProcessInput`/`ProcessBuffer`).
- **Receive queue.** `inq` holds whole messages (`{frames props}`), so multipart messages are
  atomic. `curmsg` holds the remaining frames of the message currently being read.
- **Blocking.** `Wait keys deadline` + `Notify key`. Keys are socket handles or poll ids.
  Inside a coroutine `Wait` yields; otherwise it uses `vwait`. `Notify` also schedules
  `zmq::readable` callbacks (level-triggered, via `after 0`).
- **Routing.**
  - Generic routing (load-balance out, fair-queue in) applies unless `routing.tcl` overrides it.
    REQ/REP/STREAM are still generic.
  - ROUTER/PUB/XPUB/XSUB sends never block.
  - Subscriptions are sent as legacy `\x01topic` / `\x00topic` messages; SUBSCRIBE/CANCEL
    commands are accepted.
- **Back-pressure.** `ZMQ_RCVHWM` stalls the fileevent of a pipe; `Unstall` resumes it.
  `ZMQ_SNDHWM` is not enforced (Tcl buffers output without limit).
- **Polling channels.** `zmq::poll` registers temporary fileevents on Tcl channels, restores the
  user's handlers afterwards, and must not register `writable` on read-only channels.

## Testing

- `make test` runs everything with `tclsh9.0`. `make test-tcp` also runs the tests constrained by
  `tcpTransport`, which need `connect`. `make venv` creates `.venv` with pyzmq via uv.
- `./configure --prefix=DIR` writes `config.mk` (git-ignored), which the Makefile includes.
  `make install` copies `lib/zmq/*.tcl` to `$(DESTDIR)$(LIBDIR)/zmq$(VERSION)`. VERSION is
  taken from `pkgIndex.tcl`, so bump the version only there.
- Tests source `tests/setup.tcl`. It provides these helpers:
  - `zmqerr {script}` returns e.g. `ZMQ EINVAL`.
  - `pipePair a b` connects two sockets through `chan pipe`.
  - `waitFor expr ?ms?`.
  - `rawRead chan n`.
- Interop tests against libzmq use the `pyzmq` constraint. They run python via `$::python` and
  must kill the peer in cleanup (`exec kill [pid $chan]`), otherwise a failing test hangs on
  `close`.
- New public behaviour gets tests, plus a pyzmq interop test where wire compatibility matters.

## Tooling pitfalls seen in earlier sessions

- **Batched edits.** `multi_replace_string_in_file` once landed edits at the wrong offsets and
  corrupted `engine.tcl`. Another time it reported success without changing the file. After
  edits, verify with `grep` in the terminal and run
  `echo 'lappend auto_path lib; package require zmq' | tclsh9.0`.
- **Stale reads.** `read_file` can show stale content right after an edit. Trust `grep`/`make test`.
- **Jupyter HMAC mismatches.** These usually come from text that was not UTF-8 encoded, or from
  splitting frames by position instead of at `<IDS|MSG>`. Transport is verified byte-exact
  (`tests/bytes.test`).

## Status / next steps

See `TODO.md`. The main open items are:
- tcp `connect` with reconnect, and `disconnect`.
- REQ/REP state machines; REP is needed for the Jupyter heartbeat channel.
- inproc transport.
- `ZMQ_LINGER`, heartbeats (`ZMQ_HEARTBEAT_*`), PLAIN/CURVE.

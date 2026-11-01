# Tcl API reference

`package require zmq` loads the `zmq` namespace. The commands mirror the libzmq C API:
the C function `zmq_foo(...)` becomes the Tcl command `zmq::foo ...`. Every command can also be
called through the `zmq` ensemble, e.g. `zmq socket $ctx ZMQ_REQ`.

Status markers:
- **(implemented)** works as described.
- **(partial)** works with the limitations noted.
- **(not yet)** always fails with `ENOTSUP`.

## Conventions

- **Handles.** Contexts, sockets and messages are opaque string handles (`zmqctx1`, `zmqsock3`,
  `zmqmsg2`). Using a closed handle fails with `EFAULT`, or `ENOTSOCK` for sockets.
- **Constants.** Any socket type, option, flag or property argument accepts either an integer or
  constant names. A list of names is OR-ed together, e.g. `{ZMQ_SNDMORE ZMQ_DONTWAIT}`.
  The values match `zmq.h` of libzmq 4.3.
- **Constant name forms.** Names are case-insensitive and the `ZMQ_` prefix and a leading `-` are
  optional. These are all equivalent: `ZMQ_IO_THREADS`, `IO_THREADS`, `io_threads`,
  `-io_threads`. An unknown name fails with `EINVAL` and the message `unknown constant "<name>"`.
- **Return values.** C functions that return `0`/`-1` return an empty string, or raise an error.
- **Errors.** The error has `errorCode {ZMQ <ERRNO>}`, and `zmq::errno` is set. The message is
  `zmq::strerror <ERRNO>`, or a more specific text where one helps. Error names are symbolic
  (`EAGAIN`, not a number).
- **Data.** Data is a byte string. Characters above `\xff` are rejected with `EINVAL`; convert text
  with `encoding convertto utf-8` first. Pass binary bytearrays (for example, values from
  `binary format`) directly, without text encoding.
- **Buffers.** C pointer/length pairs collapse into a single Tcl value.
- **Blocking.** Blocking calls run the Tcl event loop (`vwait`). Inside a coroutine they `yield`
  instead and are resumed when ready, which avoids nested `vwait`s.
- **Name shadowing.** `zmq::socket` and `zmq::close` shadow Tcl built-ins inside the `zmq`
  namespace. Avoid `namespace import zmq::*`.

## Library

| Command | Status | Description |
|---|---|---|
| `zmq::version` | implemented | Returns `{major minor patch}` of the emulated libzmq API (`4 3 5`). |
| `zmq::has capability` | partial | Returns `0` for every capability for now. |
| `zmq::errno` | implemented | Symbolic name of the last error, e.g. `EAGAIN`. |
| `zmq::strerror code` | implemented | Human-readable message for an error name. |
| `zmq::const name` | implemented | Integer value of a constant (Tcl-only helper). Unknown names fail with `EINVAL`. |

## Context

| Command | Status | Description |
|---|---|---|
| `zmq::ctx_new` | implemented | Creates a context and returns its handle. |
| `zmq::ctx_get ctx option` | implemented | Reads a context option. |
| `zmq::ctx_set ctx option value` | implemented | Sets a context option. Read-only or unknown options fail with `EINVAL`. |
| `zmq::ctx_shutdown ctx` | implemented | Blocked and future operations fail with `ETERM`. New sockets cannot be created. |
| `zmq::ctx_term ctx` | partial | Closes all sockets and destroys the context. It does not block waiting for `ZMQ_LINGER`. |
| `zmq::ctx_destroy ctx` | implemented | Deprecated alias of `ctx_term`. |

Context options:

| Option | Default | Access | Notes |
|---|---|---|---|
| `ZMQ_IO_THREADS` | 1 | rw | Stored only. |
| `ZMQ_MAX_SOCKETS` | 1023 | rw | Enforced: `socket` fails with `EMFILE`. |
| `ZMQ_SOCKET_LIMIT` | 65535 | r | |
| `ZMQ_MAX_MSGSZ` | 2147483647 | rw | Stored only. |
| `ZMQ_MSG_T_SIZE` | 64 | r | |
| `ZMQ_IPV6` | 0 | rw | Stored only. |
| `ZMQ_BLOCKY` | 1 | rw | Stored only. |

## Socket

| Command | Status | Description |
|---|---|---|
| `zmq::socket ctx type` | implemented | Creates a socket and returns its handle. `type` is `ZMQ_PAIR` … `ZMQ_STREAM`. |
| `zmq::close socket` | implemented | Closes listeners and connections. Pending output is flushed in the background. |
| `zmq::setsockopt socket option value` | implemented | See the socket options table below. |
| `zmq::getsockopt socket option` | implemented | See the socket options table below. |
| `zmq::bind socket endpoint` | partial | Only `tcp://` works; `inproc://` and `ipc://` are not yet. See "Endpoints". |
| `zmq::unbind socket endpoint` | implemented | Stops the listener and drops the connections it accepted. See "Endpoints". |
| `zmq::connect socket endpoint` | not yet | |
| `zmq::disconnect socket endpoint` | not yet | Fails with `ENOENT` for unknown endpoints. |
| `zmq::send socket data ?flags?` | partial | Returns the number of bytes queued. Flags: `ZMQ_SNDMORE`, `ZMQ_DONTWAIT`. See "Message routing". |
| `zmq::send_const socket data ?flags?` | partial | Same as `send`. |
| `zmq::recv socket ?flags?` | partial | Returns the next frame. Unlike C, it never truncates. Flag: `ZMQ_DONTWAIT`. See "Message routing". |
| `zmq::recv_multipart socket ?flags?` | implemented | Tcl extension. Returns all frames of the next message as a list, or the remaining frames if part of the message was already read with `recv`. Only the first frame can block; `ZMQ_DONTWAIT` applies to it. Afterwards `ZMQ_RCVMORE` is 0. |
| `zmq::send_multipart socket frames ?flags?` | implemented | Tcl extension. Sends a list of frames as one message and returns the total number of bytes. All frames are validated before anything is sent. `ZMQ_DONTWAIT` applies to the first frame; if `ZMQ_SNDMORE` is given, the message stays open after the last frame. An empty list fails with `EINVAL`. |
| `zmq::poll items ?timeout?` | implemented | Waits for socket or channel readiness and returns the list of revents. See "Polling". |
| `zmq::readable socket ?script?` | implemented | Tcl extension: registers a callback for incoming messages. See "Event callbacks". |
| `zmq::proxy frontend backend ?capture?` | not yet | |
| `zmq::proxy_steerable frontend backend ?capture? ?control?` | not yet | |
| `zmq::socket_monitor socket endpoint events` | not yet | |

### Endpoints

Endpoints use the form `transport://address`.

| Transport | Status | Address forms |
|---|---|---|
| `tcp` | bind only | `host:port`, `*:port`, `host:*`, `[ipv6]:port` |
| `inproc` | not yet | Parsed, but `bind` fails with `ENOTSUP`. |
| `ipc` | not yet | Parsed, but `bind` fails with `ENOTSUP`. |
| other | | Fails with `EPROTONOSUPPORT`. |

Address rules for `bind`:
- A malformed address fails with `EINVAL`.
- Host `*` listens on `0.0.0.0`, or on `::` when `ZMQ_IPV6` is set.
- Port `*` picks a free port.
- `ZMQ_LAST_ENDPOINT` holds the resolved endpoint, e.g. `tcp://0.0.0.0:54321`.

`bind` errors: `EADDRINUSE`, `EADDRNOTAVAIL`, and `ENODEV` for an unknown host.

`unbind` accepts the resolved endpoint. The original string also works if it contained no `*`.
Otherwise it fails with `ENOENT`.

### Message routing

| Type | Send | Receive |
|---|---|---|
| PAIR, DEALER, PUSH | round-robin over connected peers | fair-queued (PAIR, DEALER) |
| PULL | — | fair-queued |
| ROUTER | first frame = routing id of the destination | routing id of the sender is prepended |
| PUB | to every peer subscribed to the first frame | — |
| XPUB | like PUB | subscription messages (see below) |
| SUB | — | messages matching a subscription |
| XSUB | to all peers; `\x01topic` / `\x00topic` (un)subscribes | like SUB |
| REQ, REP, STREAM | generic (no request/reply state yet) | generic |

**ROUTER**
- **Routing ids.** Each peer gets a routing id. If the peer set `ZMQ_ROUTING_ID`, that value is
  used. Otherwise it is a generated 5-byte id starting with `\x00`. `msg_gets $m Routing-Id`
  returns it.
- **Duplicate ids.**
  - A second peer with an id that is already in use is disconnected.
  - With `ZMQ_ROUTER_HANDOVER` set, the new peer takes the id over instead and the old one is
    disconnected.
- **Unknown destination.** A message addressed to an unknown routing id is dropped silently.
  With `ZMQ_ROUTER_MANDATORY`, `send` of the routing id frame fails with `EHOSTUNREACH` instead.
- **Blocking.** ROUTER `send` never blocks.
- **Jupyter.** A ROUTER socket receives `{id <IDS|MSG> sig header parent metadata content}`.
  Reply by sending `{id <IDS|MSG> ...}`.

**PUB / SUB**
- **Matching.** Subscriptions are prefix matches on the first frame, and `""` matches everything.
- **Where filtering happens.** SUB sends its subscriptions to every publisher it is connected to,
  including publishers it connects to later. PUB filters on its side. SUB also filters what it
  receives.
- **Blocking.** PUB `send` never blocks. Messages for which no peer is subscribed are dropped.
  A subscriber that has just connected misses messages sent before its subscription arrives.
- **XPUB subscription messages.** XPUB delivers each new subscription to the application as
  `\x01topic`, and the cancel after the last subscriber of a topic left as `\x00topic`. This
  includes peers that disconnect. With `ZMQ_XPUB_VERBOSE`, every subscription is delivered, not
  just the first.
- **Compatibility.** Subscriptions are exchanged as ZMTP 3.0 subscription messages. ZMTP 3.1
  `SUBSCRIBE`/`CANCEL` commands are also accepted.

**`send` waits for a connected peer** (PAIR, DEALER, PUSH, REQ, REP). A message is not queued
while no peer is connected.
- With `ZMQ_DONTWAIT`, or when `ZMQ_SNDTIMEO` expires, `send` fails with `EAGAIN`.
- If a peer disconnects in the middle of a multipart message, the remaining parts are discarded.

**`recv` waits for a complete message.** It fails with `EAGAIN` under `ZMQ_DONTWAIT` or after
`ZMQ_RCVTIMEO`. Multipart messages are delivered atomically: either all parts arrive or none do.
`ZMQ_RCVMORE` reports whether more parts follow.

**Shutdown and close.** A blocked call fails with `ETERM` after `ctx_shutdown`, or with
`ENOTSOCK` if its socket is closed.

**Direction.** `send` on SUB or PULL sockets, and `recv` on PUB or PUSH sockets, fail with
`ENOTSUP`.

### Polling

`zmq::poll items ?timeout?` waits until at least one item is ready, or until the timeout expires.

- **`items`** is a list of `{handle events}` pairs.
  - `handle` is a zmq socket or any Tcl channel.
  - `events` is a mask of `ZMQ_POLLIN` and/or `ZMQ_POLLOUT`. As with other constants, names like
    `POLLIN` or `{POLLIN POLLOUT}` work.
- **`timeout`** is in milliseconds: `-1` waits forever (the default), `0` checks and returns
  immediately.
- **Return value.** Unlike C, `poll` returns a list of revents, one per item, in item order. Each
  value is masked by the events requested for that item. An all-zero list means the timeout
  expired.
- **Socket readiness.**
  - `ZMQ_POLLIN` means a message can be received without blocking.
  - `ZMQ_POLLOUT` means a send can start without blocking: a peer is connected, or a multipart
    message is in progress.
  - The same mask is available from `getsockopt $s ZMQ_EVENTS`.
- **Channel readiness.**
  - Readiness comes from `fileevent`.
  - The channel's existing `fileevent` handlers are suspended during the poll and restored
    afterwards.
  - Asking for `ZMQ_POLLOUT` on a read-only channel (or `ZMQ_POLLIN` on a write-only one) fails
    with `EINVAL`.
- **Blocking.** Like `send`/`recv`, `poll` runs the event loop while waiting, and yields when
  called inside a coroutine.
- **Errors.**
  - `ENOTSOCK` for a handle that is neither a socket nor a channel.
  - `EINVAL` for a malformed item or timeout.
  - `ETERM` once the context is shut down.

### Event callbacks (Tcl extension)

`zmq::readable socket ?script?` works like `fileevent socket readable`, but for zmq sockets.

- **Usage.**
  - With a script, it registers that script; an empty script removes the handler.
  - Without a script, it returns the current handler.
- **When it runs.** The script runs at global level from the event loop whenever the socket has a
  message to receive (`ZMQ_POLLIN`).
- **Level-triggered.** The script runs again for as long as input remains. This includes every
  remaining frame of a multipart message, so receive one frame per call.
- **Event loop.** The script only runs while the event loop is active (`vwait`, `update`, Tk, or a
  blocking zmq call).
- **Errors.**
  - If the script raises an error, the handler is removed and the error is reported through
    `interp bgerror`, as with `fileevent`.
  - Registering a script on a send-only socket (PUB, PUSH) fails with `ENOTSUP`.
- **Shutdown and close.** Handlers stop firing after `ctx_shutdown` and are discarded by `close`.

```tcl
zmq::readable $shell [list on_shell $shell]
proc on_shell {s} {
    set frames [list [zmq::recv $s]]
    while {[zmq::getsockopt $s ZMQ_RCVMORE]} {
        lappend frames [zmq::recv $s]
    }
    # handle $frames ...
}
vwait forever
```

Because the multipart message is complete once the first frame is available, reading all
frames in one call is fine. The handler is then simply not re-run for the frames already read.

### Socket options

The Notes column says whether the library acts on an option. All other options are stored and
returned, but have no effect yet.

| Option | Type | Default | Access | Notes |
|---|---|---|---|---|
| `ZMQ_AFFINITY` | int | 0 | rw | |
| `ZMQ_ROUTING_ID` (`ZMQ_IDENTITY`) | bytes | "" | rw | Sent to peers as `Identity` in the handshake. |
| `ZMQ_SUBSCRIBE` | bytes | | w | SUB/XSUB only, otherwise `EINVAL`. Enforced: sent to all connected publishers. |
| `ZMQ_UNSUBSCRIBE` | bytes | | w | SUB/XSUB only, otherwise `EINVAL`. Enforced. |
| `ZMQ_SNDBUF` | int | -1 | rw | |
| `ZMQ_RCVBUF` | int | -1 | rw | |
| `ZMQ_RCVMORE` | int | 0 | r | Enforced. |
| `ZMQ_EVENTS` | int | | r | Enforced: current `ZMQ_POLLIN`/`ZMQ_POLLOUT` mask. |
| `ZMQ_TYPE` | int | | r | Enforced. |
| `ZMQ_LINGER` | int | -1 | rw | |
| `ZMQ_RECONNECT_IVL` | int | 100 | rw | |
| `ZMQ_BACKLOG` | int | 100 | rw | |
| `ZMQ_RECONNECT_IVL_MAX` | int | 0 | rw | |
| `ZMQ_MAXMSGSIZE` | int | -1 | rw | |
| `ZMQ_SNDHWM` | int | 1000 | rw | |
| `ZMQ_RCVHWM` | int | 1000 | rw | Enforced: the socket stops reading from a peer while its queue is full. |
| `ZMQ_RCVTIMEO` | int | -1 | rw | Enforced. |
| `ZMQ_SNDTIMEO` | int | -1 | rw | Enforced. |
| `ZMQ_LAST_ENDPOINT` | string | "" | r | Enforced. |
| `ZMQ_ROUTER_MANDATORY` | int | 0 | w | Enforced: `EHOSTUNREACH` for unknown routing ids. |
| `ZMQ_TCP_KEEPALIVE` | int | -1 | rw | |
| `ZMQ_IMMEDIATE` | int | 0 | rw | |
| `ZMQ_XPUB_VERBOSE` | int | 0 | w | Enforced: report every subscription, not just the first. |
| `ZMQ_IPV6` | int | 0 | rw | Enforced: used by `bind` with host `*`. |
| `ZMQ_MECHANISM` | int | 0 (`ZMQ_NULL`) | r | Only NULL is supported. |
| `ZMQ_PROBE_ROUTER` | int | 0 | w | |
| `ZMQ_REQ_CORRELATE` | int | 0 | w | |
| `ZMQ_REQ_RELAXED` | int | 0 | w | |
| `ZMQ_CONFLATE` | int | 0 | w | |
| `ZMQ_ROUTER_HANDOVER` | int | 0 | w | Enforced: a new peer takes over a routing id that is already in use. |
| `ZMQ_HANDSHAKE_IVL` | int | 30000 | rw | |
| `ZMQ_HEARTBEAT_IVL` | int | 0 | rw | |
| `ZMQ_HEARTBEAT_TTL` | int | 0 | rw | |
| `ZMQ_HEARTBEAT_TIMEOUT` | int | -1 | rw | |
| `ZMQ_CONNECT_TIMEOUT` | int | 0 | rw | |

Error cases:
- Unknown options fail with `EINVAL`.
- Writing a read-only option, or reading a write-only one, fails with `EINVAL`.
- Integer options reject non-integers with `EINVAL`.
- `ZMQ_FD` is not supported.

## Messages

A message handle replaces `zmq_msg_t`. Release it with `msg_close`.

| Command | Status | Description |
|---|---|---|
| `zmq::msg_init` | implemented | Creates an empty message and returns its handle. |
| `zmq::msg_init_size size` | implemented | Creates a zero-filled message of `size` bytes. |
| `zmq::msg_init_data data` | implemented | Creates a message containing `data`. |
| `zmq::msg_data msg` | implemented | Returns the content. |
| `zmq::msg_size msg` | implemented | Returns the size in bytes. |
| `zmq::msg_more msg` | implemented | Returns 1 if more parts follow this frame. |
| `zmq::msg_get msg property` | implemented | `ZMQ_MORE` returns the more flag; `ZMQ_SHARED` returns 0. Anything else fails with `EINVAL`. |
| `zmq::msg_set msg property value` | implemented | Always fails with `EINVAL`, as in libzmq. |
| `zmq::msg_gets msg property` | implemented | Peer metadata: `Socket-Type`, `Identity`, `Routing-Id`, `Peer-Address` (tcp bind side), plus any other property the peer sent. Missing properties fail with `EINVAL`. |
| `zmq::msg_copy dest src` | implemented | Copies the content and properties of `src` into `dest`. |
| `zmq::msg_move dest src` | implemented | Moves the content into `dest` and empties `src`. |
| `zmq::msg_send msg socket ?flags?` | partial | Like `send`. Empties `msg` and returns the number of bytes. |
| `zmq::msg_recv msg socket ?flags?` | partial | Like `recv`. Stores the frame and its properties in `msg` and returns the size. |
| `zmq::msg_close msg` | implemented | Releases the handle. |

## Security / encoding

| Command | Status | Description |
|---|---|---|
| `zmq::z85_encode data` | implemented | Z85 (RFC 32) encoding. The length must be a multiple of 4, otherwise `EINVAL`. |
| `zmq::z85_decode string` | implemented | The length must be a multiple of 5 and contain only valid characters, otherwise `EINVAL`. |
| `zmq::curve_keypair` | not yet | |
| `zmq::curve_public secret` | not yet | |

## Error names

`EADDRINUSE`, `EADDRNOTAVAIL`, `EAGAIN`, `ECONNREFUSED`, `EFAULT`, `EFSM`, `EHOSTUNREACH`,
`EINTR`, `EINVAL`, `EMFILE`, `EMSGSIZE`, `EMTHREAD`, `ENOCOMPATPROTO`, `ENODEV`, `ENOENT`,
`ENOTSOCK`, `ENOTSUP`, `EPROTONOSUPPORT`, `ETERM`

## ZMTP codec (`zmq::zmtp`)

These are pure functions on byte strings with no I/O; the engine uses them and they are useful in
tests. Protocol violations raise an error with `errorCode {ZMTP PROTOCOL <reason>}`.

| Command | Description |
|---|---|
| `zmq::zmtp::greeting ?mechanism? ?asServer? ?minor?` | Builds the 64-byte ZMTP 3.x greeting. The defaults are `NULL 0 1`. |
| `zmq::zmtp::parse_greeting bytes` | Returns a dict with `major minor mechanism as_server`. |
| `zmq::zmtp::frame body ?more? ?command?` | Encodes a frame. Bodies over 255 bytes use the long form. |
| `zmq::zmtp::parse_frame buffer ?offset?` | Returns `{}` if the frame is incomplete. Otherwise returns a dict with `more command body length`; `length` is the number of bytes consumed. |
| `zmq::zmtp::command name ?data?` | Builds a command frame. |
| `zmq::zmtp::parse_command body` | Returns a dict with `name data`. |
| `zmq::zmtp::metadata props` | Encodes a dict as ZMTP metadata. |
| `zmq::zmtp::parse_metadata bytes` | Decodes metadata into a dict. |
| `zmq::zmtp::ready socketType ?props?` | Builds a READY command that includes `Socket-Type`. |
| `zmq::zmtp::error_command reason` | Builds an ERROR command. |
| `zmq::zmtp::compatible ours theirs` | Socket-type compatibility check from RFC 37 (type names such as `ROUTER`). |
| `zmq::zmtp::type_name type` | Converts a socket type number to its name. |

## Internal (unstable)

| Command | Description |
|---|---|
| `zmq::Attach socket rchan ?wchan? ?localProps?` | Runs ZMTP over an already connected channel (or a read/write channel pair). Transports use it, and it is the way to connect a socket until `connect` exists. Returns a connection id. |

# TODO

Goal: a pure Tcl ZeroMQ implementation that a Tcl Jupyter kernel can use.
Items marked **[J]** are needed for Jupyter. Do those first.

## Done (scaffold)
- [x] Package layout, `zmq` namespace and ensemble, constants from zmq.h
- [x] Error model (`errorCode {ZMQ <ERRNO>}`, `zmq::errno`, `zmq::strerror`)
- [x] Context lifecycle and options (`ctx_new/term/shutdown/get/set`)
- [x] Socket handles, socket option table, subscription bookkeeping
- [x] Message API (`msg_*`)
- [x] Z85 encode/decode (RFC 32)
- [x] ZMTP 3.1 codec: greeting, frames, commands, metadata, READY, type compatibility
- [x] tcltest suite plus pyzmq interop tests (gated by the `tcpTransport` constraint)

## Phase 1: Core I/O engine **[J]** (done, see `lib/zmq/engine.tcl`)
- [x] Choose the concurrency model: Tcl event loop with non-blocking channels
      (`fconfigure -blocking 0 -translation binary`, `fileevent`)
- [x] Per-connection state machine: greeting, then handshake, then READY, then traffic
- [x] Incremental read buffer that uses `zmtp::parse_frame`; Tcl's non-blocking channel buffer acts as the write queue
- [x] Blocking `send`/`recv` built on `vwait`. Inside a coroutine they `yield` instead,
      so there are no nested `vwait`s.
- [x] `ZMQ_DONTWAIT` returns `EAGAIN`; `ZMQ_RCVTIMEO`/`ZMQ_SNDTIMEO` via `after`
- [x] `ZMQ_RCVMORE`; multipart messages are atomic (deliver all frames or none)
- [x] Fill msg properties (`Socket-Type`, `Identity`/`Routing-Id`) for `msg_gets`
- [x] Peer socket-type compatibility check (drop the connection)
- [x] Handle `ERROR` command; send ERROR and close on protocol errors; answer PING with PONG
- [x] `ZMQ_RCVHWM` back-pressure (stop reading from a pipe while the queue is full)
- [x] Parse the read buffer at an offset (`zmtp::parse_frame buf ?offset?`) and trim it once per read

## Phase 2: Transports
- [x] **[J]** `tcp://` bind (`::socket -server`), including `*` port and `ZMQ_LAST_ENDPOINT` (`lib/zmq/tcp.tcl`)
- [ ] **[J]** `tcp://` connect with reconnect (`ZMQ_RECONNECT_IVL[_MAX]`)
- [x] `unbind`: closes the listener and the connections it accepted
- [ ] `disconnect`
- [ ] `inproc://` (in-memory pipes inside one interpreter, no ZMTP framing)
- [ ] IPv6 (`ZMQ_IPV6`), `source;host:port` connect syntax
- [ ] `ipc://` (Unix domain sockets are not in core Tcl; possibly via `unix_sockets` package)
- [ ] `ZMQ_IMMEDIATE`, `ZMQ_CONNECT_TIMEOUT`, `ZMQ_HANDSHAKE_IVL`
- [ ] Queue outgoing messages before a connection exists (libzmq default without `ZMQ_IMMEDIATE`);
      currently `send` waits for a ready pipe
- [ ] Bind to interface names (e.g. `tcp://eth0:5555`)
- [ ] Set `Peer-Address` message property for tcp connect (done for accepted connections)
- [x] Transports call `zmq::Attach $socket $chan` once connected

## Phase 3: Socket types
The engine's generic routing (load-balance out, fair-queue in) already fits PAIR, DEALER, PUSH and PULL.
Other types override `SendFrame`/`RecvFrame` behaviour.
- [x] Reject send/recv on sockets of the wrong direction (e.g. send on PULL gives `ENOTSUP`)
- [x] **[J]** ROUTER: shell, control and stdin channels; routing-id prefix frames; `ZMQ_ROUTER_MANDATORY`,
      `ZMQ_ROUTER_HANDOVER` (`lib/zmq/routing.tcl`)
- [x] **[J]** PUB: iopub channel; prefix filtering on the sender side
- [x] **[J]** XPUB: newer Jupyter iopub (subscription notifications, `ZMQ_XPUB_VERBOSE`)
- [ ] **[J]** REP: heartbeat channel (echo)
- [ ] DEALER, REQ (`ZMQ_REQ_CORRELATE`, `ZMQ_REQ_RELAXED`)
- [x] SUB / XSUB: subscriptions are sent as legacy messages; SUBSCRIBE/CANCEL commands are accepted
- [ ] XPUB: `ZMQ_XPUB_VERBOSER` (report every cancel), `ZMQ_XPUB_MANUAL`
- [ ] PUSH / PULL (round-robin / fair-queue)
- [ ] PAIR, STREAM
- [ ] High-water marks: `ZMQ_SNDHWM` (Tcl buffers output without limit; use `chan pending output`)
      and drop/block semantics per type

## Phase 4: Polling and event-loop integration **[J]**
- [x] `zmq::poll` over sockets and Tcl channels, with timeout
- [x] `ZMQ_EVENTS` socket option
- [x] Tcl-specific extension: `zmq::readable $socket ?script?` (like `fileevent`),
      so the kernel can be fully event driven
- [ ] `ZMQ_FD` cannot be supported directly; document the alternative

## Phase 5: Lifecycle
- [ ] `ZMQ_LINGER`: flush pending output on close/term
- [ ] `ctx_term`: blocking semantics vs. single-threaded Tcl (decide and document)
- [x] `ctx_shutdown` wakes blocked operations with `ETERM`
- [ ] ZMTP 3.1 heartbeats (PING/PONG, `ZMQ_HEARTBEAT_*`)
- [ ] Optional: thread support (one ctx per interp, or a `thread`-based I/O thread)

## Phase 6: Security
- [ ] NULL mechanism (needed by Jupyter; its HMAC signing lives in the kernel, not ZMQ)
- [ ] PLAIN mechanism (`ZMQ_PLAIN_*`)
- [ ] ZAP handler hooks (`ZMQ_ZAP_DOMAIN`)
- [ ] CURVE: needs pure Tcl Curve25519, XSalsa20 and Poly1305 (`curve_keypair`, `curve_public`).
      This is slow, so make it optional.

## Phase 7: Extras
- [ ] `zmq::proxy`, `zmq::proxy_steerable`
- [ ] `zmq::socket_monitor` (events published on a PAIR socket)
- [ ] ZMTP 1.0/2.0 peer detection and downgrade
- [ ] `ZMQ_MAXMSGSIZE` enforcement in `parse_frame`
- [ ] Case-insensitive metadata property names
- [ ] `zmq::has` reports implemented capabilities

## Testing / tooling
- [ ] Turn on the `tcpTransport` constraint in `tests/setup.tcl` once Phase 1 and 2 land
- [ ] Interop matrix against pyzmq for every socket-type pair (Tcl to libzmq and back)
- [ ] Jupyter end-to-end smoke test (`jupyter_kernel_test` or `jupyter console`)
- [ ] Fuzz `parse_frame`/`parse_metadata` with random input
- [ ] CI that runs Tcl 8.6 and 9.0
- [ ] Throughput/latency benchmark against pyzmq

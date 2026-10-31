# Common setup sourced by every *.test file.
package require tcltest 2.2
namespace import -force ::tcltest::*

set ::auto_path [linsert $::auto_path 0 \
    [file join [file dirname [file dirname [file normalize [info script]]]] lib]]
package require zmq

# Enable with: tests/all.tcl -constraints tcpTransport (make test-tcp).
testConstraint tcpTransport [expr {"tcpTransport" in [configure -constraints]}]

# Prefer the project venv (make venv).
set ::python [file join [file dirname [file dirname [file normalize [info script]]]] .venv bin python3]
if {![file executable $::python]} {
    set ::python python3
}
testConstraint pyzmq [expr {![catch {exec $::python -c "import zmq"}]}]

# Evaluate script and return the first two errorCode words, e.g. "ZMQ EINVAL".
proc zmqerr {script} {
    if {[catch {uplevel 1 $script} msg opts]} {
        return [lrange [dict get $opts -errorcode] 0 1]
    }
    return "no error: $msg"
}

# Connect two zmq sockets through a pair of in-process pipes.
proc pipePair {a b} {
    lassign [chan pipe] r1 w1
    lassign [chan pipe] r2 w2
    list [zmq::Attach $a $r1 $w2] [zmq::Attach $b $r2 $w1]
}

# Run the event loop until expr is true or timeout (ms) elapses.
proc waitFor {expr {timeout 2000}} {
    set deadline [expr {[clock milliseconds] + $timeout}]
    while {![uplevel 1 [list expr $expr]] && [clock milliseconds] < $deadline} {
        after 5 {set ::waitForTick 1}
        vwait ::waitForTick
    }
    uplevel 1 [list expr $expr]
}

# Read exactly n bytes from a raw channel while servicing the event loop.
proc rawRead {chan n {timeout 2000}} {
    fconfigure $chan -blocking 0 -translation binary
    set buf ""
    waitFor {[string length [append buf [read $chan [expr {$n - [string length $buf]}]]]] >= $n} $timeout
    return $buf
}

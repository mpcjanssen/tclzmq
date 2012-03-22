#
#  Simple Pirate queue
#  This is identical to the LRU pattern, with no reliability mechanisms
#  at all. It depends on the client for recovery. Runs forever.
#

package require zmq

set LRU_READY "READY" ;#  Signals worker is ready

#  Prepare our context and sockets
zmq context context 1
zmq socket frontend context ROUTER
zmq socket backend context ROUTER
frontend bind "tcp://*:5555" ;#  For clients
backend bind "tcp://*:5556" ;#  For workers

#  Queue of available workers
set workers {}

while {1} {
    if {[llength $workers]} {
	set poll_set [list [list backend [list POLLIN]] [list frontend [list POLLIN]]]
    } else {
	set poll_set [list [list backend [list POLLIN]]]
    }
    set rpoll_set [zmq poll $poll_set -1]
    foreach rpoll $rpoll_set {
	switch [lindex $rpoll 0] {
	    backend {
		#  Use worker address for LRU routing
		set msg [zmq zmsg_recv backend]
		set address [zmq zmsg_unwrap msg]
		lappend workers $address

		#  Forward message to client if it's not a READY
		if {[lindex $msg 0] ne $LRU_READY} {
		    zmq zmsg_send frontend $msg
		}
	    }
	    frontend {
		#  Get client request, route to first available worker
		set msg [zmq zmsg_recv frontend]
		set workers [lassign $workers worker]
		set msg [zmq zmsg_wrap $msg $worker]
		zmq zmsg_send backend $msg
	    }
	}
    }
}

frontend close
backend close
context term

[section {Polling}]

[list_begin definitions]

[call [cmd {zmq poll}] [arg pollList] [arg timeout] [opt [arg timeoutUnit]]]

Poll the specified sockets for the specifed events. A maximum timeout must be
specified. If the value of timeout is 0, the command returns immediately. If the
value of timeout is -1, the command will block indefinitely until a specified
event occurs. The polling list if specified as a list of poll requests. Such a poll request is a list of:

[list_begin enumerated]
[enum] socket
[enum] list of event flags
[list_end]

Supported event flags are:

[list_begin options]
[opt_def POLLIN]
[opt_def POLLOUT]
[list_end]

The poll command will return a list in the same format as the input polling list
with list items for each item in the original list for which an event occured
and in the list of event flags the events which occured.

[list_end]

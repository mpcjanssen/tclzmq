#
# Build zmq for static linking with the Tcl wrapper, 32 or 64 bit.
#
# Specify the ZMQDIR=<path_to_libzmq> and INSTALLDIR=<path> on the nmake command
# line
#
# Use the following commands to build and install the zmq library for 32 or 64 bit:
#
# % nmake ZMQDIR=../../libzmq INSTALLDIR=. all32
#
# % nmake ZMQDIR=../../libzmq INSTALLDIR=. all64
#

ZMQDIR = ..\..\libzmq
INSTALLDIR = .

include_HEADERS = $(ZMQDIR)\include\zmq.h $(ZMQDIR)\include\zmq_utils.h

CFLAGS = /c /I $(ZMQDIR)\include /I $(ZMQDIR)\builds\msvc /EHsc /MD /TP /D NDEBUG /D _CRT_SECURE_NO_WARNINGS /D DLL_EXPORT /D FD_SETSIZE=1024 /D _WINDOWS /D _USRDLL /D _BIND_TO_CURRENT_VCLIBS_VERSION=1 /D _MBCS /D NOMINMAX /Fo"work/"

SOURCES = \
    $(ZMQDIR)\src\address.cpp \
    $(ZMQDIR)\src\clock.cpp \
    $(ZMQDIR)\src\ctx.cpp \
    $(ZMQDIR)\src\decoder.cpp \
    $(ZMQDIR)\src\device.cpp \
    $(ZMQDIR)\src\devpoll.cpp \
    $(ZMQDIR)\src\dist.cpp \
    $(ZMQDIR)\src\encoder.cpp \
    $(ZMQDIR)\src\epoll.cpp \
    $(ZMQDIR)\src\err.cpp \
    $(ZMQDIR)\src\fq.cpp \
    $(ZMQDIR)\src\io_object.cpp \
    $(ZMQDIR)\src\io_thread.cpp \
    $(ZMQDIR)\src\ip.cpp \
    $(ZMQDIR)\src\ipc_address.cpp \
    $(ZMQDIR)\src\ipc_connecter.cpp \
    $(ZMQDIR)\src\ipc_listener.cpp \
    $(ZMQDIR)\src\kqueue.cpp \
    $(ZMQDIR)\src\lb.cpp \
    $(ZMQDIR)\src\mailbox.cpp \
    $(ZMQDIR)\src\msg.cpp \
    $(ZMQDIR)\src\mtrie.cpp \
    $(ZMQDIR)\src\object.cpp \
    $(ZMQDIR)\src\options.cpp \
    $(ZMQDIR)\src\own.cpp \
    $(ZMQDIR)\src\pair.cpp \
    $(ZMQDIR)\src\pgm_receiver.cpp \
    $(ZMQDIR)\src\pgm_sender.cpp \
    $(ZMQDIR)\src\pgm_socket.cpp \
    $(ZMQDIR)\src\pipe.cpp \
    $(ZMQDIR)\src\poll.cpp \
    $(ZMQDIR)\src\poller_base.cpp \
    $(ZMQDIR)\src\pull.cpp \
    $(ZMQDIR)\src\push.cpp \
    $(ZMQDIR)\src\reaper.cpp \
    $(ZMQDIR)\src\pub.cpp \
    $(ZMQDIR)\src\random.cpp \
    $(ZMQDIR)\src\rep.cpp \
    $(ZMQDIR)\src\req.cpp \
    $(ZMQDIR)\src\select.cpp \
    $(ZMQDIR)\src\session_base.cpp \
    $(ZMQDIR)\src\signaler.cpp \
    $(ZMQDIR)\src\socket_base.cpp \
    $(ZMQDIR)\src\stream_engine.cpp \
    $(ZMQDIR)\src\sub.cpp \
    $(ZMQDIR)\src\tcp_address.cpp \
    $(ZMQDIR)\src\tcp_connecter.cpp \
    $(ZMQDIR)\src\tcp_listener.cpp \
    $(ZMQDIR)\src\thread.cpp \
    $(ZMQDIR)\src\trie.cpp \
    $(ZMQDIR)\src\xpub.cpp \
    $(ZMQDIR)\src\router.cpp \
    $(ZMQDIR)\src\dealer.cpp \
    $(ZMQDIR)\src\xsub.cpp \
    $(ZMQDIR)\src\zmq.cpp

all64: lib64 install headers

all32: lib32 install headers

install:
	-mkdir $(INSTALLDIR)
	-mkdir $(INSTALLDIR)\lib
	copy work\libzmq.lib $(INSTALLDIR)\lib\libzmq.lib

headers: $(include_HEADERS)
	- mkdir $(INSTALLDIR)
	- mkdir $(INSTALLDIR)\include
	copy /Y $(ZMQDIR)\include\* $(INSTALLDIR)\include

lib64: objs64
	lib work\*.obj /out:work\libzmq.lib /LTCG

lib32: objs32
	lib work\*.obj /out:work\libzmq.lib /LTCG

objs64: $(SOURCES)
	- mkdir work
	cl $(SOURCES) $(CFLAGS) /D _WIN64

objs32: $(SOURCES)
	- mkdir work
	cl $(SOURCES) $(CFLAGS)

clean:
	rmdir /S /Q work

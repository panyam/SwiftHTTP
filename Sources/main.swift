
#if os(Linux)
import Glibc
srandom(UInt32(clock()))
#endif

import CoreFoundation

// How do I want this to work?
// There are two options (both require event loops):
//  Event loop use is as follows:
//      register servers
//      register callbacks
//      start runloop
//
//      As the run loop runs it will get events back on:
//      Connection received
//      Connectino closed
//      Data read
//      Data ready to be written 
//
// Now the two approaches are:
// 1. Event driven approach where each layer does its thing and sends things down stream to the next layer.
// eg:
//  As event loop gets data it calls its set of read callbacks with the data it can read and sends it to its listner (who is the server)
//  The server gets the data and sends it to the connection handler
//  The connection handler, keeps a state machine about what it is currently doing (eg reading headers, reading payload, reading frame etc)
//  Connection calls its delegates - request handler, header handler, frame handler etc to handle the corresponding frame
//  On the write side:
//      Data can be written any time the handlers choose.  
//      In Http1.0 write happens as part of a request handler (following a close)
//      In Http1.1 write can happen as part of a request but in reality write and flush are seperate things (so let connection handler do flushing and request handler do writes).
//      In websocket and http2.0, writes can happen any time but on channels - these are still "virtual" streams so connection handler would have to process these streams 
//      so we dont have interleaved writes across streams/channels.
//      An artifact of this approach is that reads can be blocked until a handler finishes processing.
//      This can be a good thing since now the client is responsible for buffering and threading and can ignore it if need be.
// 2. Call back approach where each layer performs actions with callbacks
//  The other option is to have each layer do proactive reads and wait till data is received.
//  With this approach it is intuitive and no need to maintain a state machine. 
//  But writes still have go through channel mechanism to prevent interleaved data being incorrect.
//  With this approach, the event loop will have to buffer read/write data (and data will have to be copied to/from ev side of things)

var server = CFSocketServer(port: 9999, portv6: 9999)
server.start()
var shouldKeepRunning = true        // global

while shouldKeepRunning && CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5, false) != CFRunLoopRunResult.Finished {
    print("Clocked ticked...")
}



#if os(Linux)
import Glibc
srandom(UInt32(clock()))
#endif

import CoreFoundation
import SwiftSocketServer

var server = CFSocketServerTransport()
//server.connectionFactory = EchoFactory()
server.start()

while CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5, false) != CFRunLoopRunResult.Finished {
    print("Clocked ticked...")
}


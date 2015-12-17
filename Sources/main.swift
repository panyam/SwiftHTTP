
#if os(Linux)
import Glibc
srandom(UInt32(clock()))
#endif

import CoreFoundation
import SwiftSocketServer


class HttpConnectionFactory : ConnectionFactory {
    func connectionAccepted() -> Connection {
        return HttpConnection()
    }
}

var server = CFSocketServerTransport(nil)
server.connectionFactory = HttpConnectionFactory()
server.start()

while CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5, false) != CFRunLoopRunResult.Finished {
    print("Clocked ticked...")
}


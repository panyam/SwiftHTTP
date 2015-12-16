
#if os(Linux)
import Glibc
srandom(UInt32(clock()))
#endif

import CoreFoundation
import SwiftSocketServer


class HttpFactory : ConnectionFactory {
    func connectionAccepted() -> Connection {
        return HttpConnection()
    }
}

var server = CFSocketServerTransport(nil)
server.connectionFactory = HttpFactory()
server.start()

while CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5, false) != CFRunLoopRunResult.Finished {
    print("Clocked ticked...")
}


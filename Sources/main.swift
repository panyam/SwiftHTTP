
#if os(Linux)
import Glibc
srandom(UInt32(clock()))
#endif

import CoreFoundation
import SwiftIO

class HttpConnectionFactory : ConnectionFactory {
    func createNewConnection() -> Connection {
        return SocketStream()
    }
    
    func connectionStarted(connection: Connection) {
        let sockStream = connection as! SocketStream
        let httpconn = HttpConnection(socketStream: sockStream)
        connections.append(httpconn)
        httpconn.serve()
    }
}

var connections = [HttpConnection]()

var server = CFSocketServerTransport(nil)
server.connectionFactory = HttpConnectionFactory()
server.start()

while CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5, false) != CFRunLoopRunResult.Finished {
    print("Clocked ticked...")
}


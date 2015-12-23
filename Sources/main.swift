
#if os(Linux)
import Glibc
srandom(UInt32(clock()))
#endif

import CoreFoundation
import SwiftIO

class HttpConnectionFactory : ConnectionFactory {
    func createNewConnection() -> Connection {
        return Pipe()
    }
    
    func connectionStarted(connection: Connection) {
        let pipe = connection as! Pipe
        let httpconn = HttpConnection(pipe)
        connections.append(httpconn)
        httpconn.serve()
    }
}

var connections = [HttpConnection]()

var server = CFSocketServerTransport(nil)
server.connectionFactory = HttpConnectionFactory()
server.start()

//
//func signal_handler(signo: Int32) {
//    if signo == SIGINT {
//        print("SIGINT Received")
//        server.stop()
//    }
//    else if signo == SIGSTOP {
//        print("SIGSTOP Received")
//        server.stop()
//    }
//    else if signo == SIGTERM {
//        print("SIGTERM Received")
//        server.stop()
//    }
//    else if signo == SIGKILL {
//        print("SIGKILL Received")
//        server.stop()
//    }
//}
//
//signal(SIGINT, signal_handler)
//signal(SIGSTOP, signal_handler)
//signal(SIGTERM, signal_handler)
//signal(SIGKILL, signal_handler)

while CFRunLoopRunInMode(kCFRunLoopDefaultMode, 5, false) != CFRunLoopRunResult.Finished {
    print("HTTP Clocked ticked...")
}


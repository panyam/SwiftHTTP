
#if os(Linux)
import Glibc
srandom(UInt32(clock()))
#endif

import CoreFoundation
import SwiftIO

class HttpStreamFactory : StreamFactory {
    func streamStarted(var stream: Stream) {
        stream.consumer = StreamReader(stream)
        stream.producer = StreamWriter(stream)
        let httpconn = HttpConnection(reader: stream.consumer as! Reader, writer: stream.producer as! Writer)
        connections.append(httpconn)
        httpconn.serve()
    }
}

var connections = [HttpConnection]()

var server = CFSocketServer(nil)
server.serverPort = 8888
server.streamFactory = HttpStreamFactory()
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
//    print("HTTP Clocked ticked...")
}


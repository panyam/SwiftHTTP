
#if os(Linux)
import Glibc
srandom(UInt32(clock()))
#endif

import CoreFoundation
import SwiftIO

class HttpStreamFactory : StreamFactory {
    func createNewStream() -> Stream {
        let stream = SimpleStream()
        stream.producer = StreamWriter(stream)
        stream.consumer = StreamReader(stream)
        return stream
    }
    
    func streamStarted(stream: Stream) {
        let httpconn = HttpConnection(reader: stream.consumer as! Reader, writer: stream.producer as! Writer)
        connections.append(httpconn)
        httpconn.serve()
    }
}

var connections = [HttpConnection]()

var server = CFSocketServerTransport(nil)
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
    print("HTTP Clocked ticked...")
}


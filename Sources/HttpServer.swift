//
//  HttpServer.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/25/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public class HttpServer : StreamHandler
{
    var socketServer = CFSocketServer(nil)
    var connections = [HttpConnection]()
    var requestHandler : HttpRequestHandler?
    
    public func handleStream(var stream: Stream) {
        stream.consumer = StreamReader(stream)
        stream.producer = StreamWriter(stream)
        let httpconn = HttpConnection(reader: stream.consumer as! Reader, writer: stream.producer as! Writer)
        connections.append(httpconn)
        httpconn.requestHandler = requestHandler
        httpconn.serve()
    }
    
    public func serve(handler: HttpRequestHandler)
    {
        requestHandler = handler
        socketServer.serverPort = 8888
        socketServer.streamHandler = self
        socketServer.start()
    }
}

import SwiftIO


//
//  HttpServer.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/25/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public class HttpServer : StreamHandler, HttpConnectionDelegate
{
    var socketServer = CFSocketServer(nil)
    var streams = [Stream]()
    var connections = [HttpConnection]()
    var requestHandler : HttpRequestHandler?
    var serverPort: UInt16 = 8888
    
    public init(_ httpPort: UInt16)
    {
        serverPort = httpPort
    }

    public func handleStream(var stream: Stream) {
        stream.consumer = StreamReader(stream)
        stream.producer = StreamWriter(stream)
        let httpconn = HttpConnection(reader: stream.consumer as! Reader, writer: stream.producer as! Writer)
        streams.append(stream)
        connections.append(httpconn)
        httpconn.requestHandler = requestHandler
        httpconn.delegate = self
        httpconn.serve()
    }
    
    public func serve(handler: HttpRequestHandler)
    {
        requestHandler = handler
        socketServer.serverPort = serverPort
        socketServer.streamHandler = self
        socketServer.start()
    }
    
    public func connectionFinished(connection: HttpConnection) {
        if let index = connections.indexOf({ (conn) -> Bool in return conn === connection })
        {
            connections.removeAtIndex(index)
            streams[index].close()
            streams.removeAtIndex(index)
        }
    }
}

import SwiftIO


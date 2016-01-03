//
//  HttpServer.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/25/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import SwiftIO

public protocol HttpRequestServer
{
    func handleRequest(request: HttpRequest, response: HttpResponse) -> Void
}

public class HttpServer : StreamHandler, HttpConnectionDelegate
{
    var socketServer = CFSocketServer(nil)
    var streams = [Stream]()
    var connections = [HttpConnection]()
    var requestHandler : HttpRequestHandler?
    var serverPort: UInt16 = 8888
    var connectionCount : Int = 0
    
    public init(_ httpPort: UInt16)
    {
        serverPort = httpPort
    }

    public func handleStream(var stream: Stream) {
        stream.consumer = StreamReader(stream)
        stream.producer = StreamWriter(stream)
        let httpconn = HttpConnection(reader: stream.consumer as! Reader, writer: stream.producer as! Writer)
        connectionCount += 1
        httpconn.identifier = String(format: "%03d", connectionCount)
        streams.append(stream)
        connections.append(httpconn)
        httpconn.requestHandler = requestHandler
        httpconn.delegate = self
        httpconn.serve()
    }
    
    public func connectionFinished(connection: HttpConnection) {
        if let index = connections.indexOf({ (conn) -> Bool in return conn === connection })
        {
            connections.removeAtIndex(index)
            streams[index].close()
            streams.removeAtIndex(index)
        }
    }
    
    public func serve(server: HttpRequestServer)
    {
        requestHandler = server.handleRequest
        serve()
    }
    
    public func serve(handler: HttpRequestHandler)
    {
        requestHandler = handler
        serve()
    }
    
    private func serve()
    {
        socketServer.serverPort = serverPort
        socketServer.streamHandler = self
        socketServer.start()
    }
}

//
//  WSHandler.swift
//  SwiftHTTP
//
//  Created by Sriram Panyam on 12/27/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import SwiftIO

public let WS_HANDSHAKE_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
public typealias WSHandler = (connection : WSConnection) -> Void

public class WSRequestServer : HttpRequestServer, WSConnectionDelegate {
    var handler : WSHandler

    public init(_ handler: WSHandler)
    {
        self.handler = handler
    }
    
    convenience public init (_ handler: WSConnectionHandler)
    {
        self.init(handler.handle)
    }

    public func handleRequest(request: HttpRequest, response: HttpResponse) {
        if let _ = validateRequest(request)
        {
            let connection = request.connection!
            response.setStatus(HttpStatusCode.SwitchingProtocols)
            response.headers.setValueFor("Connection", value: "Upgrade")
            response.headers.setValueFor("Upgrade", value: "websocket")
            
            let websocketKey = request.headers.firstValueFor("Sec-WebSocket-Key")!
            let websocketAcceptString = websocketKey + WS_HANDSHAKE_GUID
            let sha1Bytes = websocketAcceptString.SHA1Bytes()
            if let base64Encoded = BaseXEncoding.Base64Encode(sha1Bytes)
            {
                response.headers.setValueFor("Sec-WebSocket-Accept", value: base64Encoded)
                response.writeHeaders()
                let connection = WSConnection(connection.reader, writer: connection.writer)
                connections.append(ConnectionWrapper(connection: connection, request: request, response: response))
                connection.delegate = self
                handler(connection: connection)
                return
            }
        }

        response.setStatus(HttpStatusCode.BadRequest)
        response.close()
    }
    
    private func validateRequest(request: HttpRequest) -> NSData?
    {
        // check that the request is indeed a websocket request
        // Must have Host
        if request.hostHeader != nil &&
            request.connectionHeader?.lowercaseString == "upgrade" &&
            request.headers.firstValueFor("Upgrade")?.lowercaseString == "websocket" &&
            request.headers.firstValueFor("Sec-WebSocket-Version")?.lowercaseString == "13"
        {
            if let websocketKey = BaseXEncoding.Base64DecodeData(request.headers.firstValueFor("Sec-WebSocket-Key"))
            {
                if websocketKey.length == 16
                {
                    return websocketKey
                }
            }
        }

        return nil
    }
    
    private struct ConnectionWrapper
    {
        var connection: WSConnection
        var request: HttpRequest
        var response: HttpResponse
    }
    private var connections = [ConnectionWrapper]()
    
    public func connectionClosed(connection: WSConnection) {
        for i in 0 ..< connections.count
        {
            if connections[i].connection === connection
            {
                let wrapper = connections.removeAtIndex(i)
                let httpConnection = wrapper.request.connection!
                httpConnection.delegate?.connectionFinished(httpConnection)
                return
            }
        }
    }
}
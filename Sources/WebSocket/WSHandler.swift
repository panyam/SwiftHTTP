//
//  WSHandler.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/27/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import SwiftIO

public let WS_HANDSHAKE_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
public typealias WSHandler = (connection : WSConnection) -> Void

public class WSRequestServer : HttpRequestServer {
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
            response.setStatus(HttpStatusCode.SwitchingProtocols)
            response.headers.setValueFor("Connection", value: "Upgrade")
            response.headers.setValueFor("Upgrade", value: "websocket")
            
            let websocketAcceptString = request.headers.firstValueFor("Sec-WebSocket-Key")! + WS_HANDSHAKE_GUID
            if let base64Encoded = BaseXEncoding.Base64Encode(websocketAcceptString.SHA1Bytes())
            {
                response.headers.setValueFor("Sec-WebSocket-Accept", value: base64Encoded)
                response.writeHeaders()
                let connection = WSConnection(request.reader!, writer: response.writer!)
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
    
    private func handleWSConnection(connection: WSConnection)
    {
    }
}
//
//  CFSocketConnection.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/14/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public class CFSocketConnection : Connection {
    var clientSocket : CFSocketNativeHandle
    
    init(_ clientSock : CFSocketNativeHandle) {
        clientSocket = clientSock;
    }
}
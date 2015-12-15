//
// This source file is part of the Swiftli open source http2.0 server project
//
// Copyright (c) 2015-2016 Sriram Panyam
// Licensed under Apache License v2.0 with Runtime Library Exception
//
//
//===----------------------------------------------------------------------===//
//
//  This file implements a client transport and runloop on top of CFSocketNativeHandle.
//
//===----------------------------------------------------------------------===//

import Foundation
import Darwin
//
//#if os(Linux)
//    import SwiftGlibc
//#endif

private func handleConnectionAccept(socket: CFSocket!,
    callbackType: CFSocketCallBackType,
    address: CFData!,
    data: UnsafePointer<Void>,
    info: UnsafeMutablePointer<Void>)
{
    if (callbackType == CFSocketCallBackType.AcceptCallBack)
    {
        let socketTransport = Unmanaged<CFSocketServerTransport>.fromOpaque(COpaquePointer(info)).takeUnretainedValue()
        let clientSocket = UnsafePointer<CFSocketNativeHandle>(data)
        let clientSocketNativeHandle = clientSocket[0]
        let socketConnection = CFSocketClientTransport(clientSocketNativeHandle)
        var connection = socketTransport.connectionFactory?.connectionAccepted()
        if connection != nil
        {
            connection?.transport = socketConnection
            socketConnection.start(connection!)
        } else {
            // TODO: close the socket since no connection delegate was found
        }
        NSLog("Got connection event: \(callbackType), \(socketTransport), \(clientSocket)");
    }
}

public class CFSocketServerTransport : ServerTransport {
    /**
     * Option to ignore a request if header's exceed this length>
     */
    private var isRunning = false
    private var stopped = false
    private var serverPort : UInt16 = 0
    private var serverPortV6 : UInt16 = 0
    private var serverSocket : CFSocket?
    private var serverSocketV6 : CFSocket?
    var connectionFactory : ConnectionFactory?
    
    init(port: UInt16, portv6: UInt16) {
        serverPort = port
        serverPortV6 = portv6
    }
    
    func start() {
        NSLog("Running server")
        
        if isRunning {
            NSLog("Server is already running")
            return
        }
        
        isRunning = true
        
        initSocket()
    }
    
    private func initSocket()
    {
        let selfAsOpaque = Unmanaged<CFSocketServerTransport>.passUnretained(self).toOpaque()
        let selfAsVoidPtr = UnsafeMutablePointer<Void>(selfAsOpaque)
        var socketContext = CFSocketContext(version: 0, info: selfAsVoidPtr, retain: nil, release: nil, copyDescription: nil)
        withUnsafePointer(&socketContext) {
            serverSocket = CFSocketCreate(kCFAllocatorDefault, PF_INET, 0, 0, 2, handleConnectionAccept, UnsafePointer<CFSocketContext>($0));
        }

        var sin = sockaddr_in();
        sin.sin_len = UInt8(sizeof(sockaddr_in));
        sin.sin_family = sa_family_t(AF_INET);
        sin.sin_port = UInt16(serverPort).bigEndian
        sin.sin_addr.s_addr = 0
        let sin_len = sizeof(sockaddr_in)
        
        withUnsafePointer(&sin) { //(<#UnsafePointer<T>#>) -> Result in
            let sincfd = CFDataCreate(
                kCFAllocatorDefault,
                UnsafePointer($0),
                sin_len);
            let err = CFSocketSetAddress(serverSocket, sincfd);
            if err != CFSocketError.Success {
                let errstr : String? =  String.fromCString(strerror(errno));
                NSLog ("Socket Set Address Error: \(err.rawValue), \(errno), \(errstr)")
            }
        }

        let socketSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, serverSocket, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), socketSource, kCFRunLoopDefaultMode)
    }

    private func asUnsafeMutableVoid() -> UnsafeMutablePointer<Void>
    {
        let selfAsOpaque = Unmanaged<CFSocketServerTransport>.passUnretained(self).toOpaque()
        let selfAsVoidPtr = UnsafeMutablePointer<Void>(selfAsOpaque)
        return selfAsVoidPtr
    }
    
    private func initSocketV6()
    {
        var socketContext = CFSocketContext(version: 0, info: self.asUnsafeMutableVoid(), retain: nil, release: nil, copyDescription: nil)
        withUnsafePointer(&socketContext) {
            serverSocketV6 = CFSocketCreate(kCFAllocatorDefault, PF_INET6, 0, 0, 2, handleConnectionAccept, UnsafePointer<CFSocketContext>($0));
        }
        
        // Bind v6 socket
        var sin6 = sockaddr_in6();
        sin6.sin6_len = UInt8(sizeof(sockaddr_in6));
        sin6.sin6_family = sa_family_t(AF_INET6);
        sin6.sin6_port = UInt16(serverPortV6).bigEndian
        sin6.sin6_addr = in6addr_any;
        let sin6_len = sizeof(sockaddr_in)
        
        withUnsafePointer(&sin6) { //(<#UnsafePointer<T>#>) -> Result in
            let sincfd = CFDataCreate(
                kCFAllocatorDefault,
                UnsafePointer($0),
                sin6_len);
            CFSocketSetAddress(serverSocketV6, sincfd);
        }

        let socketSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, serverSocketV6, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), socketSource, kCFRunLoopDefaultMode)
    }

    func stop() {
    }
}


//
//  WSPMCE.swift
//  SwiftHTTP
//
//  Created by Sriram Panyam on 1/23/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import SwiftIO

public class WSPMCEFactory : WSExtensionFactory
{
    public init()
    {
    }
    
    public func createExtension(name: String, arguments: [(String, String)]) -> WSExtension? {
        let out = WSPMCEExtension(name)
        for (arg, value) in arguments
        {
            switch arg {
            case "server_no_context_takeover": out.serverNoContextTakeover = true
            case "server_max_window_bits":
                if let intValue = Int(value) {
                    out.serverMaxWindowBits = 1 << intValue
                } else if value != "" {
                    return nil
                }
            case "client_no_context_takeover": out.clientNoContextTakeover = true
            case "client_max_window_bits":
                if let intValue = Int(value) {
                    out.clientMaxWindowBits = 1 << intValue
                } else if value != "" {
                    return nil
                }
            default: return nil
            }
        }
        return out
    }
}

public class WSPMCEExtension : WSExtension
{
    /**
     * Compression algorithm used - only deflate supported for now
     */
    public var compressionType = "deflate"
    public var serverNoContextTakeover = false
    public var serverMaxWindowBits = 32768
    public var clientNoContextTakeover = false
    public var clientMaxWindowBits = 32768
    
    private var currentFrame : WSFrame = WSFrame()
    
    override public var negotiationResponseString : String {
        get {
            var out = "\(name)"
            if serverNoContextTakeover {
                out += "; server_no_context_takeover"
            }
            return out
        }
    }
    
    /**
     * Called when a new frame has been read.
     * This can either modify the original frame or a return a new frame
     * after extension processing the frame.
     * If an error is returned then the connection can get closed.
     */
    override public func newFrameRead(frame : WSFrame) -> (WSFrame, ErrorType?)
    {
        currentFrame = frame
        var outFrame = frame
        outFrame.reserved1Set = false
        return (outFrame, nil)
    }
}
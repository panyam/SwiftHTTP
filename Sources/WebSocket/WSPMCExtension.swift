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
    
    override public var negotiationResponseString : String {
        get {
            var out = "\(name)"
            if serverNoContextTakeover {
                out += "; server_no_context_takeover"
            }
            return out
        }
    }
}
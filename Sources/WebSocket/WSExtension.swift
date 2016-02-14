//
//  WSExtension.swift
//  SwiftHTTP
//
//  Created by Sriram Panyam on 1/23/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import SwiftIO

public class WSExtension
{
    public var name : String
    public var arguments = [(String, String)]()
    
    public init(_ name : String)
    {
        self.name = name
    }

    public var negotiationResponseString : String {
        get {
            return "\(name)"
        }
    }
    
    /** 
     * Called when a new frame has been read. 
     * This can either modify the original frame or a return a new frame 
     * after extension processing the frame.
     * If an error is returned then the connection can get closed.
     */
    public func newFrameRead(frame : WSFrame) -> (WSFrame, ErrorType?)
    {
        return (frame, nil)
    }
}


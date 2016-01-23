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
}


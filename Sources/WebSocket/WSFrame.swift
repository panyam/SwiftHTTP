//
//  WSFrame.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/30/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public struct WSFrame
{
    var payloadLength : UInt64 = 0
    var opcode : UInt8 = 0
    var isMasked : Bool = false
    var isFinal : Bool = false
    var maskingKey : UInt32 = 0
}
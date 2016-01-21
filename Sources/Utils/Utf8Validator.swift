//
//  Utf8Validator.swift
//  SwiftHTTP
//
//  Created by Sriram Panyam on 1/20/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import SwiftIO

public class Utf8Validator
{
    // Size of the current char.  The first byte in the sequence dictates how many bytes are to follow
    private var utf8CurrSize : UInt = 0
    // Index of the current char we are validating
    private var utf8CurrIndex : UInt = 0
    private var utf8CurrRealValue : UInt = 0
    private var utf8CurrByteValue : UInt = 0
    
    public func reset()
    {
        utf8CurrSize = 0
        utf8CurrIndex = 0
        utf8CurrRealValue = 0
        utf8CurrByteValue = 0
    }

    public func validate(buffer: ReadBufferType, _ length: LengthType) -> Bool
    {
        for i in 0 ..< length {
            print("\(String(buffer[i], radix: 16)) -> \(String(buffer[i], radix: 2))")
            if utf8CurrIndex == 0 {
                utf8CurrByteValue = UInt(buffer[i]) & 0xff
                utf8CurrRealValue = UInt(buffer[i]) & 0x7f
                // we are at the first byte so get character size
                if buffer[i] & 0x80 == 0 {
                    // do nothing go to the next char
                    utf8CurrSize = 1
                } else {
                    if ((buffer[i] >> 5) & 0xff) == 0x06 {     // 110
                        utf8CurrSize = 2
                    } else if ((buffer[i] >> 4) & 0xff) == 0x0E {     // 1110
                        utf8CurrSize = 3
                    } else if ((buffer[i] >> 3) & 0xff) == 0x1E {     // 11110
                        utf8CurrSize = 4
                    } else {
                        // invalid continuation sequence
                        return false
                    }
                    utf8CurrIndex += 1
                }
            } else {
                if ((buffer[i] >> 6) & 0xff) != 0x02 {     // 10
                    return false
                }
                utf8CurrByteValue = (utf8CurrByteValue << 8) | (UInt(buffer[i]) & 0xff)
                let numBitsToShift = (utf8CurrIndex == 0 ? (utf8CurrSize + 1) : 2)
                let numBitsToUse = 8 - numBitsToShift
                utf8CurrRealValue = (utf8CurrRealValue << numBitsToShift) | (UInt(buffer[i]) & ((1 << numBitsToUse) - 1))
                utf8CurrIndex += 1
                if utf8CurrIndex >= utf8CurrSize {
                    // check for invalid sequences
                    if utf8CurrRealValue > 0x10ffff {
                        Log.debug("Invalid \(utf8CurrSize) byte utf8 char at position: \(i): 0x\(String(utf8CurrRealValue, radix: 16))")
                        return false
                    }
                    if utf8CurrRealValue >= 0xd800 && utf8CurrRealValue <= 0xdfff
                    {
                        Log.debug("Invalid \(utf8CurrSize) byte utf8 char at position: \(i): 0x\(String(utf8CurrRealValue, radix: 16))")
                        return false
                    }
                    // check overlong encodings
                    if utf8CurrSize == 2 {
                        if utf8CurrByteValue == 0xc080
                        {
                            Log.debug("Invalid \(utf8CurrSize) byte utf8 char at position: \(i): 0x\(String(utf8CurrRealValue, radix: 16))")
                            return false
                        }
                        else if utf8CurrRealValue < 0x80 || utf8CurrRealValue > 0x07ff {
                            Log.debug("Invalid \(utf8CurrSize) byte utf8 char at position: \(i): 0x\(String(utf8CurrRealValue, radix: 16))")
                            return false
                        }
                    }
                    else if utf8CurrSize == 3 {
                        if utf8CurrRealValue < 0x0800 || utf8CurrRealValue > 0xffff {
                            Log.debug("Invalid \(utf8CurrSize) byte utf8 char at position: \(i): 0x\(String(utf8CurrRealValue, radix: 16))")
                            return false
                        }
                    }
                    else if utf8CurrSize == 4 {
                        if utf8CurrRealValue < 0x010000 || utf8CurrRealValue > 0x1fffff {
                            Log.debug("Invalid \(utf8CurrSize) byte utf8 char at position: \(i): 0x\(String(utf8CurrRealValue, radix: 16))")
                            return false
                        }
                    }

                    utf8CurrIndex = 0
                    utf8CurrByteValue = 0
                    utf8CurrRealValue = 0
                }
            }
        }
        return true
    }
    
    public func finish() -> Bool
    {
        return utf8CurrIndex == 0
    }
}
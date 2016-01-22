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
    // Utf8 Decoding State Machine based on:
    // http://bjoern.hoehrmann.de/utf-8/decoder/dfa/
    public static let UTF8_ACCEPT : UInt = 0
    public static let UTF8_REJECT : UInt = 1
    private static let utf8d : [UInt] = [
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 00..1f
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 20..3f
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 40..5f
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 60..7f
        1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9, // 80..9f
        7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7, // a0..bf
        8,8,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, // c0..df
        0xa,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x4,0x3,0x3, // e0..ef
        0xb,0x6,0x6,0x6,0x5,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8, // f0..ff
        0x0,0x1,0x2,0x3,0x5,0x8,0x7,0x1,0x1,0x1,0x4,0x6,0x1,0x1,0x1,0x1, // s0..s0
        1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,0,1,0,1,1,1,1,1,1, // s1..s2
        1,2,1,1,1,1,1,2,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1, // s3..s4
        1,2,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,3,1,3,1,1,1,1,1,1, // s5..s6
        1,3,1,1,1,1,1,3,1,3,1,1,1,1,1,1,1,3,1,1,1,1,1,1,1,1,1,1,1,1,1,1, // s7..s8
    ];
    
    private var currentState : UInt = Utf8Validator.UTF8_ACCEPT
    private var currentCodePoint : UInt = 0
    
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

    private func logAndFail(index: LengthType) -> Bool {
        Log.debug("Invalid \(utf8CurrSize) byte utf8 char at position (\(index)): 0x\(String(utf8CurrRealValue, radix: 16)), ByteSeq: 0x\(String(utf8CurrByteValue, radix: 16))")
        return false
    }

    private func nextByte(byte : UInt8) -> UInt {
        let type = Utf8Validator.utf8d[Int(byte)];
        
        currentCodePoint = (currentState != Utf8Validator.UTF8_ACCEPT) ?
                                (UInt(byte) & 0x3f) | (currentCodePoint << 6) :
                                ((0xff >> type) & UInt(byte));
        currentState = Utf8Validator.utf8d[Int(256 + currentState * 16 + type)];
        return currentState
    }

    public func validate(buffer: ReadBufferType, _ length: LengthType) -> Bool
    {
        for i in 0 ..< length {
            if nextByte(buffer[i]) == Utf8Validator.UTF8_REJECT
            {
                return false
            }
        }
        return true
    }
    
    public func finish() -> Bool
    {
        return currentState == Utf8Validator.UTF8_ACCEPT
    }
    
    public func validate2(buffer: ReadBufferType, _ length: LengthType) -> Bool
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
                        return logAndFail(i)
                    }
                    if utf8CurrRealValue >= 0xd800 && utf8CurrRealValue <= 0xdfff
                    {
                        return logAndFail(i)
                    }
                    // check overlong encodings
                    if utf8CurrSize == 2 {
                        if utf8CurrByteValue == 0xc080
                        {
                            return logAndFail(i)
                        }
                        else if utf8CurrRealValue < 0x80 || utf8CurrRealValue > 0x07ff {
                            return logAndFail(i)
                        }
                    }
                    else if utf8CurrSize == 3 {
                        if utf8CurrRealValue < 0x0800 || utf8CurrRealValue > 0xffff {
                            return logAndFail(i)
                        }
                    }
                    else if utf8CurrSize == 4 {
                        if utf8CurrRealValue < 0x010000 || utf8CurrRealValue > 0x1fffff {
                            return logAndFail(i)
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
    
    public func finish2() -> Bool
    {
        return utf8CurrIndex == 0
    }
}
//
//  WSFrame.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/30/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import SwiftIO

public struct WSFrame
{
    var payloadLength : UInt64 = 0
    var opcode : UInt8 = 0
    var isMasked : Bool = false
    var isFinal : Bool = false
    var maskingKey : UInt32 = 0
}

/**
 * The frame reader is the low level reader of all frames and returns raw data
 * from the frames (after unmasking and after stripping out the headers).
 *
 * The way a client would use this is by starting a frame with startFrame
 * and then repeatedly calling read until it returns an EndReached error.
 *
 * If startFrame returns an error then no more frames are available.
 */
public class WSFrameReader
{
    public typealias FrameStartCallback = (frame: WSFrame?, error : ErrorType?) -> Void
    public typealias FrameReadCallback = IOCallback
    private enum ReadState
    {
        case UNSTARTED
        case READING_HEADER
        case READING_PAYLOAD
    }
    private var readState : ReadState = ReadState.READING_HEADER
    private var reader : StatefulReader
    private var currFrameLength : UInt64 = 0
    private var currFrameSatisfied : UInt64 = 0
    private var currFrameType : UInt8 = 0
    private var currFrameIsMasked : Bool = false
    private var currFrameIsFinal : Bool = false
    private var currFrameMaskingKey : UInt32 = 0
    
    /**
     * The current frame being read
     */
    public var currentFrame : WSFrame {
        get
        {
            return WSFrame(payloadLength: currFrameLength,
                opcode: currFrameType,
                isMasked: currFrameIsMasked,
                isFinal: currFrameIsFinal,
                maskingKey: currFrameMaskingKey)
        }
    }
    
    public init(_ reader : Reader)
    {
        self.reader = StatefulReader(reader)
    }

    /**
     * Called to start a new frame.  If this is called when a frame has already been
     * started, then nothing happens.
     */
    public func start(callback : FrameStartCallback)
    {
        if readState != ReadState.UNSTARTED
        {
            return callback(frame: nil, error: nil)
        }
        
        reset()
        
        func readMaskingKeyAndContinue(callback : FrameStartCallback)
        {
            if !self.currFrameIsMasked
            {
                self.currFrameMaskingKey = 0
                self.readState = ReadState.READING_PAYLOAD
                return callback(frame: self.currentFrame, error: nil)
            }
            
            self.reader.readUInt32 { (value, error) -> Void in
                self.currFrameMaskingKey = value
                self.readState = ReadState.READING_PAYLOAD
                callback(frame: self.currentFrame, error: nil)
            }
        }

        // read type and first length bit
        reader.consume({ (reader) -> (finished: Bool, error: ErrorType?) in
            self.reader.readInt16 { (value, error) -> Void in
                self.currFrameLength = UInt64(value & Int16((1 << 7) - 1))
                value >> 7
                
                self.currFrameIsMasked = ((value & Int16(1)) == 1)
                value >> 1
                
                self.currFrameType = UInt8(value & Int16((1 << 4) - 1))
                value >> 7

                self.currFrameIsFinal = ((value & Int16(1)) == 1)
                value >> 1
                
                if self.currFrameLength == 126
                {
                    // 2 byte payload length
                    self.reader.readUInt16({ (value, error) -> Void in
                        self.currFrameLength = UInt64(value)
                        readMaskingKeyAndContinue(callback)
                    })
                } else if self.currFrameLength == 127
                {
                    // 8 byte payload length
                    self.reader.readUInt64({ (value, error) -> Void in
                        self.currFrameLength = value
                        readMaskingKeyAndContinue(callback)
                    })
                } else {
                    readMaskingKeyAndContinue(callback)
                }
            }
            return (true, nil)
        }, onError: { (error) -> ErrorType? in
            return error
        })
    }

    /**
     * Called to read the payload in a frame until it exists
     */
    public func read(buffer : ReadBufferType, length: Int, callback : FrameReadCallback)
    {
        if self.readState != ReadState.READING_PAYLOAD || currFrameSatisfied >= currFrameLength
        {
            reset()
            return callback(length: 0, error: IOErrorType.EndReached)
        }
        
        let realLength = min(length, Int(currFrameLength - currFrameSatisfied))
        reader.read(buffer, length: realLength) { (length, error) -> () in
            assert(length <= realLength, "Underlying reader may be broken - gave us too many bytes")
            let endReached = IOErrorType.EndReached.equals(error)
            var finalError = error
            if error == nil || endReached
            {
                self.currFrameSatisfied += UInt64(length)
                if self.currFrameSatisfied >= self.currFrameLength
                {
                    finalError = IOErrorType.EndReached
                }
                // TODO: unmask the data
            }
            callback(length: length, error: finalError)
        }
    }
    
    private func reset()
    {
        readState = ReadState.UNSTARTED
        currFrameSatisfied = 0
        currFrameLength = 0
        currFrameType = 0
        currFrameIsMasked = false
        currFrameMaskingKey = 0
        currFrameIsFinal = true
    }
}

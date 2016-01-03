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
    public static let MAX_CONTROL_FRAME_SIZE = 125
    public static let DEFAULT_CHANNEL_ID = ""
    
    public enum Opcode : UInt8
    {
        case ContinuationFrame = 0
        case TextFrame = 1
        case BinaryFrame = 2
        case CloseFrame = 8
        case PingFrame = 9
        case PongFrame = 10
    }
    
    /**
     * Which channel a frame belongs to.
     * In a multiplexed connection a single connection can be used to
     * multiplex several logical connection (eg multiple tabs in a browser
     * all opening websocket connections to a single endpoint).  
     * This ID determines which channel the frame belongs to and is determined
     * by the extension that is processing a frame as it is being read.
     */
    public var channelId : String = DEFAULT_CHANNEL_ID
    public var payloadLength : LengthType = 0
    public var opcode = Opcode.ContinuationFrame
    public var isMasked : Bool = false
    public var isFinal : Bool = false
    public var maskingKey : UInt32 = 0
    
    public var isControlFrame : Bool {
        get {
            return opcode == .CloseFrame || opcode == .PingFrame || opcode == .PongFrame
        }
    }
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
public class WSFrameReader : Reader
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
    private var currFrameChannelId = WSFrame.DEFAULT_CHANNEL_ID
    private var currFrameLength : LengthType = 0
    private var currFrameSatisfied : LengthType = 0
    private var currFrameOpcode = WSFrame.Opcode.ContinuationFrame
    private var currFrameIsMasked : Bool = false
    private var currFrameIsFinal : Bool = false
    private var currFrameMaskingKey : UInt32 = 0
    
    /**
     * The current frame being read
     */
    public var currentFrame : WSFrame {
        get
        {
            return WSFrame(channelId: currFrameChannelId,
                payloadLength: currFrameLength,
                opcode: currFrameOpcode,
                isMasked: currFrameIsMasked,
                isFinal: currFrameIsFinal,
                maskingKey: currFrameMaskingKey)
        }
    }
    
    public var stream : Stream {
        return reader.stream
    }
    
    public init(_ reader : Reader)
    {
        self.reader = StatefulReader(reader)
    }
    
    public var isIdle : Bool {
        return readState == .UNSTARTED || currFrameSatisfied >= currFrameLength
    }
    
    public var readingHeader : Bool {
        return readState == .READING_HEADER
    }
    
    public var readingPayload : Bool {
        return readState == .READING_PAYLOAD && currFrameSatisfied < currFrameLength
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
            
            self.reader.readUInt32 { (value, error) in
                self.currFrameMaskingKey = value
                self.readState = ReadState.READING_PAYLOAD
                callback(frame: self.currentFrame, error: nil)
            }
        }

        // read type and first length bit
        reader.consume({ (reader) -> (finished: Bool, error: ErrorType?) in
            self.reader.readInt16 { (value, error) in
                self.currFrameLength = LengthType(value & Int16((1 << 7) - 1))
                value >> 7
                
                self.currFrameIsMasked = ((value & Int16(1)) == 1)
                value >> 1
                
                // TODO: validate opcode types
                self.currFrameOpcode = WSFrame.Opcode(rawValue: UInt8(value & Int16((1 << 4) - 1)))!
                value >> 7

                self.currFrameIsFinal = ((value & Int16(1)) == 1)
                value >> 1
                
                if self.currFrameLength == 126
                {
                    // 2 byte payload length
                    self.reader.readUInt16({ (value, error) in
                        self.currFrameLength = LengthType(value)
                        readMaskingKeyAndContinue(callback)
                    })
                } else if self.currFrameLength == 127
                {
                    // 8 byte payload length
                    self.reader.readUInt64({ (value, error) in
                        self.currFrameLength = LengthType(value)
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
    
    public var bytesAvailable : LengthType {
        if self.readState != ReadState.READING_PAYLOAD || currFrameSatisfied >= currFrameLength
        {
            reset()
            return 0
        } else {
            return reader.bytesAvailable
        }
    }
    
    public func read() -> (value: UInt8, error: ErrorType?) {
        if self.readState != ReadState.READING_PAYLOAD || currFrameSatisfied >= currFrameLength
        {
            reset()
            return (0, IOErrorType.Unavailable)
        } else {
            // TODO: unmask the data
            return reader.read()
        }
    }

    /**
     * Called to read the payload in a frame until it exists
     */
    public func read(buffer : ReadBufferType, length: LengthType, callback : FrameReadCallback?)
    {
        if self.readState != ReadState.READING_PAYLOAD || currFrameSatisfied >= currFrameLength
        {
            reset()
            callback?(length: 0, error: IOErrorType.EndReached)
            return
        }

        let realLength = min(length, currFrameLength - currFrameSatisfied)
        reader.read(buffer, length: realLength) { (length, error) in
            assert(length <= realLength, "Underlying reader may be broken - gave us too many bytes")
            let endReached = IOErrorType.EndReached.equals(error)
            var finalError = error
            if error == nil || endReached
            {
                self.currFrameSatisfied += LengthType(length)
                if self.currFrameSatisfied >= self.currFrameLength
                {
                    finalError = IOErrorType.EndReached
                }
                // TODO: unmask the data
            }
            callback?(length: length, error: finalError)
        }
    }
    
    private func reset()
    {
        readState = ReadState.UNSTARTED
        currFrameSatisfied = 0
        currFrameLength = 0
        currFrameOpcode = WSFrame.Opcode.ContinuationFrame
        currFrameIsMasked = false
        currFrameMaskingKey = 0
        currFrameIsFinal = true
    }
}

public class WSFrameWriter
{
    private var writer : Writer
    public init(_ writer : Writer)
    {
        self.writer = writer
    }
}


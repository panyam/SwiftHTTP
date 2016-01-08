//
//  WSFrame.swift
//  SwiftHTTP
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
        case ReservedNonControl3 = 3
        case ReservedNonControl4 = 4
        case ReservedNonControl5 = 5
        case ReservedNonControl6 = 6
        case ReservedNonControl7 = 7
        case CloseFrame = 8
        case PingFrame = 9
        case PongFrame = 10
        case ReservedControl11 = 11
        case ReservedControl12 = 12
        case ReservedControl13 = 13
        case ReservedControl14 = 14
        case ReservedControl15 = 15
        
        public var isControlCode : Bool {
            return self.rawValue >= CloseFrame.rawValue
        }
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
    public var maskingKeyBytes :[UInt8] = [0,0,0,0]

    public static func parseMaskingKeyBytes(value: UInt32) -> [UInt8]
    {
        return [
            UInt8((value >> 24) & UInt32(0xff)),
            UInt8((value >> 16) & UInt32(0xff)),
            UInt8((value >> 8) & UInt32(0xff)),
            UInt8(value & UInt32(0xff))
        ]
    }
    
    public var isControlFrame : Bool {
        return opcode == .CloseFrame || opcode == .PingFrame || opcode == .PongFrame
    }
    
    public var isStartFrame : Bool {
        return opcode != .ContinuationFrame
    }
}

public class WSFrameProcessor
{
    enum State
    {
        case UNSTARTED
        case HEADER
        case PAYLOAD
    }
    var state : State = State.UNSTARTED
    var currFrameChannelId = WSFrame.DEFAULT_CHANNEL_ID
    var currFrameLength : LengthType = 0
    var currFrameSatisfied : LengthType = 0
    var currFrameOpcode = WSFrame.Opcode.ContinuationFrame
    var currFrameIsMasked : Bool = false
    var currFrameIsFinal : Bool = false
    var currFrameMaskingKey : UInt32 = 0
    var currFrameMaskingKeyBytes :[UInt8] = [0,0,0,0]
    
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
                maskingKey: currFrameMaskingKey,
                maskingKeyBytes: currFrameMaskingKeyBytes)
        }
    }
    
    public var isIdle : Bool {
        return state == .UNSTARTED
//        if state == .UNSTARTED
//        {
//            return true
//        }
//        if currFrameSatisfied >= currFrameLength
//        {
//            if currFrameSatisfied != 0
//            {
//                reset()
//            }
//            return true
//        }
//        return  false
    }
    
    public var processingHeader : Bool {
        return state == .HEADER
    }
    
    public var processingPayload : Bool {
        return state == .PAYLOAD
//        if state != .PAYLOAD
//        {
//            return false
//        }
//        
//        if currFrameSatisfied < currFrameLength
//        {
//            return true
//        }
//        if currFrameSatisfied > 0
//        {
//            reset()
//        }
//        return false
    }
    
    private func reset()
    {
        state = .UNSTARTED
        currFrameSatisfied = 0
        currFrameLength = 0
        currFrameOpcode = WSFrame.Opcode.ContinuationFrame
        currFrameIsMasked = false
        currFrameMaskingKey = 0
        currFrameMaskingKeyBytes = [0,0,0,0]
        currFrameIsFinal = true
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
public class WSFrameReader : WSFrameProcessor
{
    public typealias FrameStartCallback = (frame: WSFrame?, error : ErrorType?) -> Void
    public typealias FrameReadCallback = IOCallback
    private var reader : Reader
    
    public init(_ reader : Reader)
    {
        self.reader = reader
    }

    /**
     * Called to start a new frame.  If this is called when a frame has already been
     * started, then nothing happens.
     */
    public func start(callback : FrameStartCallback)
    {
        if !isIdle
        {
            return callback(frame: nil, error: nil)
        }
        
        reset()
        
        func readMaskingKeyAndContinue(callback : FrameStartCallback)
        {
            if !currFrameIsMasked
            {
                currFrameMaskingKey = 0
                currFrameMaskingKeyBytes = [0,0,0,0]
                state = State.PAYLOAD
                return callback(frame: self.currentFrame, error: nil)
            }
            
            self.reader.readUInt32 { (value, error) in
                self.currFrameMaskingKey = value
                self.currFrameMaskingKeyBytes = WSFrame.parseMaskingKeyBytes(self.currFrameMaskingKey)
                self.state = .PAYLOAD
                callback(frame: self.currentFrame, error: error)
            }
        }

        // read type and first length bit
        self.reader.readUInt16 { (var value, error) in
            self.currFrameLength = LengthType(value & UInt16((1 << 7) - 1))
            value = value >> 7
            
            self.currFrameIsMasked = ((value & UInt16(1)) == 1)
            value = value >> 1
            
            // TODO: validate opcode types
            self.currFrameOpcode = WSFrame.Opcode(rawValue: UInt8(value & 0x0f))!
            value = value >> 7
            
            self.currFrameIsFinal = ((value & UInt16(1)) == 1)
            value = value >> 1
            
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
    }
    
    public var bytesReadable : LengthType {
        if state != .PAYLOAD || currFrameSatisfied >= currFrameLength
        {
            reset()
            return 0
        } else {
            return reader.bytesReadable
        }
    }
    
    public func read() -> (value: UInt8, error: ErrorType?) {
        if state != .PAYLOAD || currFrameSatisfied >= currFrameLength
        {
            reset()
            return (0, IOErrorType.Unavailable)
        } else {
            var (out, error) = reader.read()
            if error == nil
            {
                if currFrameMaskingKey != 0
                {
                    let mask = currFrameMaskingKeyBytes[currFrameSatisfied % 4]
                    out ^= UInt8(mask)
                }
                currFrameSatisfied++
            }
            return (out, error)
        }
    }

    /**
     * Called to read the payload in a frame until it exists
     */
    public func read(buffer : ReadBufferType, length: LengthType, callback : FrameReadCallback?)
    {
        if state != .PAYLOAD || currFrameSatisfied >= currFrameLength
        {
            reset()
            callback?(length: 0, error: IOErrorType.EndReached)
            return
        }

        let realLength = min(length, currFrameLength - currFrameSatisfied)
        reader.read(buffer, length: realLength) { (length, error) in
            assert(length <= realLength, "Underlying reader may be broken - gave us too many bytes")
            let endReached = (error as? IOErrorType) == IOErrorType.EndReached
            var finalError = error
            if error == nil || endReached
            {
                self.currFrameSatisfied += LengthType(length)
                if self.currFrameMaskingKey != 0
                {
                    let firstIndex = self.currFrameSatisfied - length
                    for i in firstIndex ..< self.currFrameSatisfied
                    {
                        let mask = self.currFrameMaskingKeyBytes[i % 4]
                        buffer[i - firstIndex] ^= UInt8(mask)
                    }
                }
                if self.currFrameSatisfied >= self.currFrameLength || endReached
                {
                    // all the bytes in the frame read so set state to IDLE
                    finalError = IOErrorType.EndReached
                    self.reset()
                }
            }
            callback?(length: length, error: finalError)
        }
    }
}

/**
 * The frame reader is the low level writer of all frames .
 *
 * The way a client would use this is by starting a frame with startFrame
 * and then repeatedly calling read until it returns an EndReached error.
 *
 * If startFrame returns an error then no more frames are available.
 */
public class WSFrameWriter : WSFrameProcessor, Writer
{
    public typealias FrameStartCallback = (frame: WSFrame?, error : ErrorType?) -> Void
    public typealias FrameWriteCallback = IOCallback
    private var writer : Writer
    private var producer : DataWriter

    public var stream : Stream {
        return writer.stream
    }
    
    public init(_ writer : Writer)
    {
        self.writer = writer
        self.producer = DataWriter(writer)
    }
    
    /**
     * Called to start a new frame.  If this is called when a frame has already been
     * started, then nothing happens.
     */
    public func start(var opcode: WSFrame.Opcode, frameLength: LengthType, isFinal: Bool, maskingKey: UInt32, callback : FrameStartCallback)
    {
        if !isIdle
        {
            return callback(frame: nil, error: nil)
        }
        
        reset()
        state = .UNSTARTED
        currFrameSatisfied = 0
        currFrameLength = frameLength
        currFrameOpcode = opcode
        currFrameIsMasked = maskingKey != 0
        currFrameMaskingKey = maskingKey
        currFrameMaskingKeyBytes = WSFrame.parseMaskingKeyBytes(maskingKey)
        currFrameIsFinal = isFinal

        var numLengthBytes = 0
        
        // TODO: Handle RSVD 1/2/3 and 3 based on extensions
        var opcodeAndLength1 : LengthType = LengthType((isFinal ? 0x80 : 0x00) | (opcode.rawValue)) << 8
        if frameLength <= 125
        {
            opcodeAndLength1 |= (frameLength & 0xff)
        } else if frameLength <= (1 << 16)
        {
            opcodeAndLength1 |= (126 & 0xff)
        } else // 64 bits
        {
            opcodeAndLength1 |= (127 & 0xff)
        }

        producer.writeUInt16(UInt16(opcodeAndLength1)) { (error) -> Void in
            if error != nil
            {
                return callback(frame: self.currentFrame, error: error)
            }

            func writeMaskingKeyAndContinue(completion : FrameStartCallback)
            {
                if !self.currFrameIsMasked
                {
                    self.state = .PAYLOAD
                    return completion(frame: self.currentFrame, error: nil)
                }
                
                self.producer.writeUInt32(self.currFrameMaskingKey) { (error) in
                    self.state = .PAYLOAD
                    completion(frame: self.currentFrame, error: error)
                }
            }

            if frameLength <= 125
            {
                // go to masking key
                writeMaskingKeyAndContinue(callback)
            } else if frameLength <= (1 << 16)  // 32 bit length
            {
                self.producer.writeUInt32(UInt32(frameLength & 0xffff), callback: { (error) -> Void in
                    writeMaskingKeyAndContinue(callback)
                })
            } else // 64 bits
            {
                self.producer.writeUInt64(UInt64(frameLength), callback: { (error) -> Void in
                    writeMaskingKeyAndContinue(callback)
                })
            }
        }
    }

    public func flush(callback: CompletionCallback?) {
        self.writer.flush(callback)
    }
    
    public func write(var value: UInt8, _ callback: CompletionCallback?) {
        if state != .PAYLOAD || currFrameSatisfied >= currFrameLength
        {
            reset()
            callback?(error: IOErrorType.Unavailable)
        } else {
            if currFrameMaskingKey != 0
            {
                let mask = currFrameMaskingKeyBytes[currFrameSatisfied % 4]
                value ^= UInt8(mask)
            }
            currFrameSatisfied++
            return writer.write(value, callback)
        }
    }
    
    public func write(buffer: WriteBufferType, length: LengthType, _ callback: IOCallback?) {
        if state != .PAYLOAD
        {
            reset()
            callback?(length: 0, error: IOErrorType.EndReached)
            return
        }
        
        let realLength = min(length, currFrameLength - currFrameSatisfied)
        var index = currFrameSatisfied % 4
        if currFrameIsMasked && currFrameMaskingKey != 0
        {
            // mask the data
            let mask = currFrameMaskingKeyBytes[index]
            for i in 0 ..< realLength
            {
                buffer[i] = buffer[i] ^ UInt8(mask)
            }
            index = (index + 1) % 4
        }

        writeRaw(buffer, length: length, callback)
    }
    
    /**
     * Called to write the bound-checked and masked data continuosly till
     * all requested data has been written (or errored out)
     */
    private func writeRaw(buffer: WriteBufferType, length: LengthType, _ callback: IOCallback?)
    {
        let requestedLength = length
        writer.write(buffer, length: length) { (length, error) -> Void in
            assert(length <= requestedLength, "Underlying reader may be broken - gave us too many bytes")
            let endReached = (error as? IOErrorType) == IOErrorType.EndReached
            var finalError = error
            if error == nil || endReached
            {
                self.currFrameSatisfied += LengthType(length)
                if self.currFrameSatisfied >= self.currFrameLength
                {
                    finalError = IOErrorType.EndReached
                    self.reset()
                } else {
                    // more data left so call write again
                    return self.writeRaw(buffer.advancedBy(length), length: requestedLength - length, callback)
                }
            }
            callback?(length: length, error: finalError)
        }
    }
}

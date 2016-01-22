//
//  WSConnection.swift
//  SwiftHTTP
//
//  Created by Sriram Panyam on 12/30/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import SwiftIO

public typealias WSCallback = (message: WSMessage) -> Void

public protocol WSConnectionDelegate
{
    /**
     * Connection was closed.
     */
    func connectionClosed(connection: WSConnection)
}

public protocol WSConnectionHandler
{
    func handle(connection: WSConnection)
}

public class WSConnection
{
    public typealias ClosedCallback = Void -> Void
    public typealias MessageCallback = (message: WSMessage) -> Void

    var delegate : WSConnectionDelegate?
    private var frameReader: WSFrameReader
    private var messageReader : WSMessageReader
    private var frameWriter: WSFrameWriter
    private var messageWriter : WSMessageWriter

    public var onMessage : MessageCallback?
    public var onClosed : ClosedCallback?
    private var controlFrameBuffer : ReadBufferType = ReadBufferType.alloc(256)

    public init(_ reader: Reader, writer: Writer)
    {
        self.frameReader = WSFrameReader(reader)
        self.messageReader = WSMessageReader(frameReader)
        self.frameWriter = WSFrameWriter(writer)
        self.messageWriter = WSMessageWriter(frameWriter)

        messageReader.onControlFrame = self.handleControlFrame
        messageReader.onClosed = {
            self.connectionClosed()
        }
        messageReader.onMessage = {(message) in
            self.onMessage?(message: message)
        }
        messageWriter.onClosed = {
            self.connectionClosed()
        }

        start()
        // So at this point we have a frame reader from which *something* can 
        // consume frames.  So messages (and channels) are a higher level 
        // abstraction on top of frames.  We have a message object from which
        // data can be read.   So how to tie these two together?
        // There will be a single consumer to the frame reader as everything is
        // a FIFO stream of frames.  The consumer to the frame reader will be
        // a messager splitter or demultiplexer - it will take each frame and decide
        // which channel the frame needs to go to (including control frames).
    }
    
    public func start()
    {
        self.messageReader.start()
    }
    
    /**
     * Starts a new message tha
     t can be streamed out by the caller.
     * Once a message is created it can be written to continuosly.
     */
    public func startMessage(opcode: WSFrame.Opcode) -> WSMessage
    {
        return self.messageWriter.startMessage(opcode)
    }
    
    /**
     * Appends more data to a message.
     */
    public func write(message: WSMessage, maskingKey: UInt32, source: Payload, isFinal: Bool, callback: CompletionCallback?)
    {
        self.messageWriter.write(message, maskingKey: maskingKey, source: source, isFinal: isFinal, callback: callback)
    }
    
    /**
     * Appends more data to a message.
     */
    public func write(message: WSMessage, source: Payload, isFinal: Bool, callback: CompletionCallback?)
    {
        self.messageWriter.write(message, maskingKey: 0, source: source, isFinal: isFinal, callback: callback)
    }
    
    /**
     * Appends more data to a message.
     */
    public func write(message: WSMessage, source: Payload, callback: CompletionCallback?)
    {
        self.messageWriter.write(message, maskingKey: 0, source: source, isFinal: false, callback: callback)
    }
    
    /**
     * Closes the message.  This message can no longer be written to.
     */
    public func closeMessage(message: WSMessage, callback: CompletionCallback?)
    {
        self.messageWriter.closeMessage(message, callback: callback)
        self.messageReader.continueReading()
    }
    
    public func read(message: WSMessage, buffer : ReadBufferType, length: LengthType, fully: Bool, callback: WSMessageReadCallback?)
    {
        self.messageReader.read(message, buffer: buffer, length: length, fully: fully, callback: callback)
    }
    
    private func handleControlFrame(frame: WSFrame, completion: CompletionCallback?)
    {
        if frame.reserved1Set || frame.reserved2Set || frame.reserved3Set
        {
            self.connectionClosed()
            completion?(error: nil)
        } else
        {
            self.frameReader.read(controlFrameBuffer, length: frame.payloadLength, fully: true) { (length, error) -> Void in
                if error != nil {
                    completion?(error: error)
                } else {
                    if frame.opcode == WSFrame.Opcode.PingFrame || frame.opcode == WSFrame.Opcode.CloseFrame
                    {
                        assert(frame.payloadLength == length, "Read fully didnt read fully!")
                        var source = BufferPayload(buffer: self.controlFrameBuffer, length: length)
                        Log.debug("\n\nControl Frame \(frame.opcode) Length: \(frame.payloadLength)")
                        if frame.payloadLength > 0 {
                            let code : UInt = ((UInt(self.controlFrameBuffer[0]) << 8) & 0xff00) | (UInt(self.controlFrameBuffer[1]) & 0xff)
                            if code < 1000 || (code >= 1004 && code <= 1006) || (code >= 1012 && code < 3000) || (code >= 5000){
                                // invalid close codes
                                let codeBuffer = ReadBufferType.alloc(2)
                                codeBuffer[0] = 0x03
                                codeBuffer[1] = 0xEA
                                source = BufferPayload(buffer: codeBuffer, length: 2)
                            }
                            else if length > 2 {
                                if let utf8String = NSString(data: NSData(bytes: self.controlFrameBuffer.advancedBy(2), length: length - 2), encoding: NSUTF8StringEncoding)
                                {
                                    Log.debug("Received UTF8 payload: \(utf8String)")
                                } else {
                                    let codeBuffer = ReadBufferType.alloc(2)
                                    codeBuffer[0] = 0x03
                                    codeBuffer[1] = 0xEA
                                    source = BufferPayload(buffer: codeBuffer, length: 2)
                                }
                            }
                        }
                        let replyCode = frame.opcode == WSFrame.Opcode.PingFrame ? WSFrame.Opcode.PongFrame : WSFrame.Opcode.CloseFrame
                        let message = self.startMessage(replyCode)
                        self.messageWriter.write(message, maskingKey: 0, source: source, isFinal: true, callback: completion)
                    } else {
                        // ignore others (but finish their payloads off first)!
                        completion?(error: nil)
                    }
                }
            }
        }
    }
    
    private func connectionClosed()
    {
        self.delegate?.connectionClosed(self)
        self.onClosed?()
    }
}

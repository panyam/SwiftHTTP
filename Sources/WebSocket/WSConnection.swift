//
//  WSConnection.swift
//  SwiftHTTP
//
//  Created by Sriram Panyam on 12/30/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import SwiftIO

public typealias WSCallback = (message: WSMessage) -> Void

/**
 * A message read/write request that is queued and processed FIFO.
 */
private class WSMessageRequest
{
//    var currentFrame : WSFrame
}

public protocol WSConnectionHandler
{
    func handle(connection: WSConnection)
}

public class WSConnection
{
    private struct WSReadRequest
    {
        var message : WSMessage
        var buffer : ReadBufferType
        var fully : Bool = false
        var length : LengthType
        var satisfied : LengthType = 0
        var callback : IOCallback?
        
        var remaining : LengthType
        {
            return length - satisfied
        }
    }

    public typealias ClosedCallback = Void -> Void
    public typealias MessageCallback = (message: WSMessage) -> Void

    private var frameReader: WSFrameReader
    private var messageReader : WSMessageReader
    private var frameWriter: WSFrameWriter
    private var messageWriter : WSMessageWriter

    public var onMessage : MessageCallback?
    public var onClosed : ClosedCallback?
    
    public init(_ reader: Reader, writer: Writer)
    {
        self.frameReader = WSFrameReader(reader)
        self.messageReader = WSMessageReader(frameReader)
        self.frameWriter = WSFrameWriter(writer)
        self.messageWriter = WSMessageWriter(frameWriter)

        messageReader.onClosed = {
            self.onClosed?()
        }
        messageReader.onMessage = {(message) in
            self.onMessage?(message: message)
        }
        messageWriter.onClosed = {
            self.onClosed?()
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
     * Adds a message writer to the the queue of writes that
     * will be handled along with all other writes.
     */
    public func write(opcode: WSFrame.Opcode, maskingKey: UInt32, source: Payload, callback: CompletionCallback?)
    {
        self.messageWriter.write(opcode, maskingKey: maskingKey, source: source, callback: callback)
    }
    
    public func read(message: WSMessage, buffer : ReadBufferType, length: LengthType, callback: IOCallback?)
    {
        self.messageReader.read(message, buffer: buffer, length: length, callback: callback)
    }
}

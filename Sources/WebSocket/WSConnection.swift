//
//  WSConnection.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/30/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import SwiftIO

public class WSMessage
{
    /**
     * Message type being sent
     */
    var messageType : UInt8 = 0
    
    /**
     * Returns the length of the message.
     * If the message length is not known then nil is returned.
     * If the message length is unknown then the "beginFrame"
     * method can be called which MUST be return the new frame's 
     * length as well as whether there are more frames.
     */
    public func totalLength() -> Int?
    {
        return nil
    }
    
    /**
     * Reads the body
     */
    public func read(data : ReadBufferType, length: Int, callback: IOCallback)
    {
    }
    
    var extraDataDict = [String : Any]()
    public func extraData(key: String) -> Any?
    {
        return extraDataDict[key]
    }
    
    public func setExtraData(key: String, value: Any?)
    {
        if value == nil {
            extraDataDict.removeValueForKey(key)
        } else {
            extraDataDict[key] = value!
        }
    }
}

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
    public typealias ClosedCallback = Void -> Void
    public typealias MessageCallback = (message: WSMessage) -> Void

    private var reader: WSFrameReader
    private var writer: Writer
    private var maxFrameSize = 8192
    private var frameWriteQueue = [WSMessageRequest]()
    private var frameReadQueue = [WSMessageRequest]()
    private var currentReadRequest : WSMessageRequest?
    private var currentWriteRequest : WSMessageRequest?
    
    public init(_ reader: Reader, writer: Writer)
    {
        self.reader = WSFrameReader(reader)
        self.writer = writer
    }

    /**
     * Gets the next message in the stream.
     * Returns a WSMessageReader via the callback which can be used
     * to read upto totalLength number of bytes in total.
     */
    public func onMessage(callback: MessageCallback)
    {
    }
    
    public func onClosed(callback : ClosedCallback)
    {
    }

    /**
     * Adds a message writer to the the queue of writes that 
     * will be handled along with all other writes.
     */
    public func sendMessage(opcode: UInt8, maskingKey: Int32?, source: Payload, callback: WSCallback)
    {
    }
}

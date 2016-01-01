//
//  WSPayload.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/31/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import SwiftIO

public typealias PayloadWriteCallback = (error: ErrorType?) -> Void
public protocol Payload
{
    /**
     * Returns the length of the message to be sent out (before fragmentation)
     * If the message size is unknown at this time then this information MUST
     * be returned during the frame creation.
     * If during frame creation the length is unknown then it is assumed
     * that a single frame is to be sent for this message.
     * The opcodes and masking keys are already provided during the call to
     * connection.sendMessage
     */
    var totalLength : UInt? { get }
    
    /**
     * If the message length above is not given then frames can be specified
     * by the message source explicitly to indicate framing per message.
     */
    var frameLength : UInt? { get }

    /**
     * Called to write the next set of bytes to the underlying channel.
     */
    func write(writer: Writer, completion: PayloadWriteCallback)
}

/**
 * A http writer of strings
 */
public class StringPayload : Payload
{
    var value : String
    
    public init(_ stringValue : String)
    {
        value = stringValue
    }
    
    public var totalLength : UInt? {
        get {
            return UInt(value.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        }
    }

    public var frameLength : UInt?
    {
        get {
            return nil
        }
    }
    
    public func write(writer: Writer, completion: PayloadWriteCallback)
    {
        writer.writeString(value) { (length, error) -> () in
            completion(error: error)
        }
    }
}

public class BufferPayload : Payload
{
    var buffer : ReadBufferType
    var length : UInt
    
    convenience public init(buffer : ReadBufferType, length: Int)
    {
        self.init(buffer: buffer, length: UInt(length))
    }

    public init(buffer : ReadBufferType, length: UInt)
    {
        self.buffer = buffer
        self.length = length
    }
    
    public var totalLength : UInt? {
        get {
            return length
        }
    }
    
    /**
     * If the message length above is not given then frames can be specified
     * by the message source explicitly to indicate framing per message.
     */
    public var frameLength : UInt?
    {
        get {
            return nil
        }
    }

    /**
     * Called to write the next set of bytes to the underlying channel.
     */
    public func write(writer: Writer, completion: PayloadWriteCallback)
    {
        writer.write(buffer, length: Int(self.length)) { (length, error) -> () in
            completion(error: error)
        }
    }
}

public class FilePayload : Payload
{
    var filePath : String
    var fileSize : UInt?
    var dataBuffer = ReadBufferType.alloc(DEFAULT_BUFFER_LENGTH)
    
    var reader : StreamReader
    var fileAttrs : [String : AnyObject]?
    
    public init(_ path: String)
    {
        filePath = path
        fileSize = SizeOfFile(filePath)
        reader = FileReader(filePath)
    }
    
    public var totalLength : UInt?
    {
        get
        {
            return fileSize
        }
    }
    
    public var frameLength : UInt?
    {
        get {
            return nil
        }
    }
    
    public func write(writer: Writer, completion: PayloadWriteCallback)
    {
        var totalWritten = 0
        func readSender()
        {
            reader.read(dataBuffer, length: DEFAULT_BUFFER_LENGTH) { (length, error) -> () in
                if error != nil || length == 0 {
                    completion(error: error)
                } else {
                    writer.write(self.dataBuffer, length: length) { (length, error) -> () in
                        if error != nil {
                            completion(error: error)
                        } else {
                            totalWritten += length
                            readSender()
                        }
                    }
                }
            }
        }
        readSender()
    }
}

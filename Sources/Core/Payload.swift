//
//  WSPayload.swift
//  SwiftHTTP
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
    var totalLength : LengthType? { get }
    
    /**
     * If the message length above is not given then this method can be called to 
     * begin the "next" frame of the message which *must* have a length.
     * If this method returns 0 then there are no more frames available.
     */
    func nextFrame() -> LengthType?

    /**
     * Called to write the next length set of bytes to the underlying channel.
     * If the source tries to write more than length number of bytes the underlying
     * writer may throw an EndReached error.  It can however write less than length
     * number of bytes (eg if it applies compression).
     *
     * A length of 0 indicates to the payload source that it can write as many bytes as it has.
     */
    func write(writer: Writer, length: LengthType, completion: PayloadWriteCallback)
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
    
    public var totalLength : LengthType? {
        get {
            return LengthType(value.lengthOfBytesUsingEncoding(NSUTF8StringEncoding))
        }
    }

    public func nextFrame() -> LengthType? {
        return nil
    }

    /**
     * Called to write the next length set of bytes to the underlying channel.
     * If the source tries to write more than length number of bytes the underlying
     * writer may throw an EndReached error.  It can however write less than length
     * number of bytes (eg if it applies compression).
     */
    public func write(writer: Writer, length: LengthType, completion: PayloadWriteCallback)
    {
        writer.writeString(value) { (length, error) -> () in
            completion(error: error)
        }
    }
}

public class BufferPayload : Payload
{
    var buffer : ReadBufferType
    var offset : OffsetType = 0
    var length : LengthType

    public init(buffer : ReadBufferType, length: LengthType)
    {
        self.buffer = buffer
        self.length = length
    }
    
    public var totalLength : LengthType? {
        return length
    }
    
    /**
     * If the message length above is not given then frames can be specified
     * by the message source explicitly to indicate framing per message.
     */
    public func nextFrame() -> LengthType? {
        return nil
    }
    
    /**
     * Called to write the next length set of bytes to the underlying channel.
     * If the source tries to write more than length number of bytes the underlying
     * writer may throw an EndReached error.  It can however write less than length
     * number of bytes (eg if it applies compression).
     */
    public func write(writer: Writer, length: LengthType, completion: PayloadWriteCallback)
    {
        writer.write(buffer, length: LengthType(length)) { (length, error) -> () in
            completion(error: error)
        }
    }
}

public class FilePayload : Payload
{
    var filePath : String
    var offset : OffsetType = 0
    var fileSize : LengthType?
    var dataBuffer = ReadBufferType.alloc(DEFAULT_BUFFER_LENGTH)
    
    var reader : StreamReader
    var fileAttrs : [String : AnyObject]?
    
    public init(_ path: String)
    {
        filePath = path
        fileSize = SizeOfFile(filePath)
        reader = FileReader(filePath)
    }
    
    public var totalLength : LengthType?
    {
        return fileSize
    }
    
    public func nextFrame() -> LengthType? {
        return nil
    }
    
    /**
     * Called to write the next length set of bytes to the underlying channel.
     * If the source tries to write more than length number of bytes the underlying
     * writer may throw an EndReached error.  It can however write less than length
     * number of bytes (eg if it applies compression).
     */
    public func write(writer: Writer, length: LengthType, completion: PayloadWriteCallback)
    {
        var totalWritten = 0
        assert(false, "Come back to this")
        func readSender()
        {
            reader.read(dataBuffer, length: DEFAULT_BUFFER_LENGTH) { (length, error) in
                if error != nil || length == 0 {
                    completion(error: error)
                } else {
                    writer.write(self.dataBuffer, length: length) { (length, error) in
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

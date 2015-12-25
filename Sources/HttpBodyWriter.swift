//
//  HttpBodyWriter.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/24/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import SwiftIO

/**
 * Responsible for generating payload for a http response.
 * This can be used any time payload is expected for a response or a frame
 * within a response.
 */
public protocol HttpBodyWriter {
    /**
     * Begins writing to the Writer and calls the callback when data has been written with the number of bytes written or with an error.
     */
    func write(writer: Writer, callback: ((numWritten: Int, error: ErrorType?) -> ())?)
    
    /**
     * Returns an optional content length
     * If no content length is returned then it is upto the writer
     * to transfer encode the data as it sees fit.
     */
    func contentLength() -> Int?
}

/**
 * A http writer of strings
 */
public class StringBodyWriter : HttpBodyWriter
{
    var value : String
    
    public init(_ stringValue : String)
    {
        value = stringValue
    }
    
    public func contentLength() -> Int? {
        return value.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
    }
    
    public func write(writer: Writer, callback: ((numWritten: Int, error: ErrorType?) -> ())?) {
        writer.writeString(value) { (length, error) -> () in
            callback?(numWritten: length, error: error)
        }
    }
}

public class FileBodyWriter : HttpBodyWriter
{
    var filePath : String
    public init(_ path: String)
    {
        filePath = path
    }
    
    public func contentLength() -> Int? {
        return 0
    }
    
    public func write(writer: Writer, callback: ((numWritten: Int, error: ErrorType?) -> ())?) {
//        writer.writeString(value) { (buffer, length, error) -> () in
//            callback?(numWritten: length, error: error)
//        }
    }
}

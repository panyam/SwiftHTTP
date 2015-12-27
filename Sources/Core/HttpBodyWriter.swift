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
    func contentLength() -> UInt64?
    
    /**
     * Give the body generator a chance to decorate the response by changing
     * response codes, headers etc
     */
    func decorateResponse(response: HttpResponse)
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
    
    public func contentLength() -> UInt64? {
        let len = value.lengthOfBytesUsingEncoding(NSUTF8StringEncoding)
        return UInt64(len)
    }
    
    public func write(writer: Writer, callback: ((numWritten: Int, error: ErrorType?) -> ())?) {
        writer.writeString(value) { (length, error) -> () in
            callback?(numWritten: length, error: error)
        }
    }
    
    public func decorateResponse(response: HttpResponse) {
        // does nothing
    }
}

public class FileBodyWriter : HttpBodyWriter
{
    var filePath : String
    var fileSize : UInt64?
    var dataBuffer = BufferType.alloc(DEFAULT_BUFFER_LENGTH)
    
    var reader : StreamReader
    var fileAttrs : [String : AnyObject]?
    
    public init(_ path: String)
    {
        filePath = path
        fileSize = SizeOfFile(filePath)
        reader = FileReader(filePath)
    }
    
    public func contentLength() -> UInt64? {
        return fileSize
    }
    
    public func decorateResponse(response: HttpResponse) {
        // TODO: Check file stats and readability etc
        // check file attributes
        do {
            fileAttrs = try NSFileManager.defaultManager().attributesOfItemAtPath(filePath)
            
            if fileAttrs == nil {
                response.setStatus(404, "Not Found")
            } else {
                if (fileAttrs![NSFileType] as! String) != NSFileTypeRegular {
                    // unable to get it so send a Not found
                    response.setStatus(400, "Bad Request")
                }
            }
        } catch {
            // unable to get it so send a Not found
            response.setStatus(400, "Bad Request")
        }
    }
    
    public func write(writer: Writer, callback: ((numWritten: Int, error: ErrorType?) -> ())?) {
        var totalWritten = 0
        reader.read(dataBuffer, length: DEFAULT_BUFFER_LENGTH) { (length, error) -> () in
            if error != nil || length == 0 {
                callback?(numWritten: totalWritten, error: error)
            } else {
                writer.write(self.dataBuffer, length: length, callback: { (length, error) -> () in
                    if error != nil {
                        callback?(numWritten: totalWritten, error: error)
                    } else {
                        totalWritten += length
                        self.write(writer, callback: callback)
                    }
                })
            }
        }
    }
}

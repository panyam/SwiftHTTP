//
//  WSReader.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/30/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import SwiftIO

/**
 * Provides a reader interface over a buffered reader that transparently (to the caller) 
 * handles control frames, fragmentation and extension processing.
 */
public class WSFrameReader : Reader
{
    var reader : StatefulReader

    /**
     * Whether we are reading header or payload of a given frame
     */
    var readingHeader : Bool = true
    var currentFrame : WSFrame = WSFrame()
    var readBuffer = ReadBufferType.alloc(8192)
    private enum WSFrameReadState
    {
        case READING_UNSTARTED
        case READING_HEADER
        case READING_PAYLOAD
    }
    private var readState : WSFrameReadState = WSFrameReadState.READING_HEADER
    
    public init(_ reader: Reader)
    {
        self.reader = StatefulReader(reader)
    }
    
    public var bytesAvailable : Int {
        get {
            return reader.bytesAvailable
        }
    }
    
    public func read() -> (value: UInt8, error: ErrorType?) {
        return reader.read()
    }

    public func read(buffer: ReadBufferType, length: Int, callback: IOCallback?)
    {
        if readState == WSFrameReadState.READING_UNSTARTED
        {
            readState = WSFrameReadState.READING_HEADER
            readHeader({ (frame, error) -> Void in
                if error != nil {
                    self.readState = WSFrameReadState.READING_UNSTARTED
                    callback?(length: 0, error: error)
                    return
                }
                self.readState = WSFrameReadState.READING_PAYLOAD
                self.currentFrame = frame!
            })
        }
    }
    
    private func readHeader(callback : (frame: WSFrame?, error: ErrorType?) -> Void)
    {
        reader.readInt16 { (value, error) in
            if error != nil {
                return callback(frame: nil, error: error)
            }
        }
    }
}
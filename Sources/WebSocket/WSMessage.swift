//
//  WSMessage.swift
//  swiftli
//
//  Created by Sriram Panyam on 1/1/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import SwiftIO

public class WSMessage
{
    /**
     * Message type being sent
     */
    var messageType : UInt8 = 0
    
    /**
     * Reads the body
     */
    public func read(data : ReadBufferType, length: Int, callback: IOCallback?)
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

/**
 * A wrapper around a reader to read websocket frames
 */
public class WSMessageReader : Reader
{
    /**
     * Message type being sent
     */
    var messageType : UInt8 = 0
    
    private var dataBuffer : Buffer = Buffer()
    
    public var bytesAvailable : Int {
        get {
            return dataBuffer.length
        }
    }
    
    public func read() -> (value: UInt8, error: ErrorType?) {
        if dataBuffer.length == 0
        {
            return (0, IOErrorType.Unavailable)
        } else {
            return (dataBuffer.advanceBy(0), nil)
        }
    }
    
    /**
     * Reads the body
     */
    public func read(data : ReadBufferType, length: Int, callback: IOCallback?)
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

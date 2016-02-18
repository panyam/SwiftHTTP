//
//  ObservableStreams.swift
//  SwiftHttp
//
//  Created by Sriram Panyam on 02/10/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import RxSwift
import SwiftIO

public class CallbackStreamConsumer : StreamConsumer {
    public var onError : ((error : ErrorType) -> Void)?
    public var onDataReceivable : ((receiver: DataReceiver) -> Bool)?
    public var onDataRequested : (Void -> (buffer: UnsafeMutablePointer<UInt8>, length: LengthType)?)?
    public var onDataReceived : ((length: LengthType) -> Void)?
    public var onClosed : (Void -> Void)?
    
    /**
     * Called when read error received.
     */
    public func receivedReadError(error: ErrorType)
    {
        onError?(error: error)
    }
    
    /**
     * Called when the stream has data to be received.
     * receiver.read Can called by the consumer until data is left.
     */
     //    func canReceiveData(receiver: DataReceiver) -> Bool
     
     /**
     * Called by the stream when it can pass data to be processed.
     * Returns a buffer (and length) into which at most length number bytes will be filled.
     */
    public func readDataRequested() -> (buffer: UnsafeMutablePointer<UInt8>, length: LengthType)?
    {
        return onDataRequested?()
    }
    
    /**
     * Called when the stream has data to be received.
     * receiver.read Can called by the consumer until data is left.
     */
    public func canReceiveData(receiver: DataReceiver) -> Bool
    {
        if let onDataReceivable = onDataReceivable {
            return onDataReceivable(receiver: receiver)
        }
        return false
    }
    
    /**
     * Called to process data that has been received.
     * It is upto the caller of this interface to consume *all* the data
     * provided.
     * @param   length  Number of bytes read.  0 if EOF reached.
     */
    public func dataReceived(length: LengthType)
    {
        onDataReceived?(length: length)
    }
    
    /**
     * Called when the parent stream is closed.
     */
    public func streamClosed() {
        onClosed?()
    }
}

public class RxStreamConsumer : CallbackStreamConsumer {
    public class ReadEvent {
    }

    /**
     * Get the observer associated with this consumer.
     * There can only be one.
     */
    public func observer() {
    }
}

func rxStreamConsumer() {
    let consumer = CallbackStreamConsumer()
    consumer.onClosed = {
    }
    consumer.onError = {error in
    }
    consumer.onDataReceivable = {receiver in
        return false
    }
    consumer.onDataReceived = {length in
    }
    consumer.onDataRequested = {
        return (nil,0)
    }
//    public var onDataRequested : (Void -> (buffer: UnsafeMutablePointer<UInt8>, length: LengthType)?)?
//    public var onDataReceived : ((length: LengthType) -> Void)?
}


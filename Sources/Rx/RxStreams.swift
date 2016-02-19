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
    public func canReceiveData(receiver: DataReceiver) -> Bool
    {
        if let onDataReceivable = onDataReceivable {
            return onDataReceivable(receiver: receiver)
        }
        return false
    }
    
     /**
     * Called by the stream when it can pass data to be processed.
     * Returns a buffer (and length) into which at most length number bytes will be filled.
     */
    public func readDataRequested() -> (buffer: UnsafeMutablePointer<UInt8>, length: LengthType)?
    {
        assert(false, "not implemented")
    }
    
    /**
     * Called to process data that has been received.
     * It is upto the caller of this interface to consume *all* the data
     * provided.
     * @param   length  Number of bytes read.  0 if EOF reached.
     */
    public func dataReceived(length: LengthType)
    {
        assert(false, "not implemented")
    }
    
    /**
     * Called when the parent stream is closed.
     */
    public func streamClosed() {
        onClosed?()
    }
}


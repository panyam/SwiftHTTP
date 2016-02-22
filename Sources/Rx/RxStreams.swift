//
//  ObservableStreams.swift
//  SwiftHttp
//
//  Created by Sriram Panyam on 02/10/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import RxSwift
import SwiftIO

public class CallbackStreamConsumer : StreamConsumer, Pausable {
    public var onError : ((error : ErrorType) -> Void)?
    public var onDataReceivable : ((receiver: DataReceiver) -> Bool)?
    public var onClosed : (Void -> Void)?
    private var theStream : Stream
    
    public init(_ stream: Stream)
    {
        self.theStream = stream
    }
    
    public func pause() {
        theStream.clearReadyToRead()
    }
    
    public func resume() {
        theStream.setReadyToRead()
    }

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
     * Called when the parent stream is closed.
     */
    public func streamClosed() {
        onClosed?()
    }
}


public class CallbackStreamProducer : StreamProducer, Pausable {
    public var onError : ((error : ErrorType) -> Void)?
    public var onDataSendable : ((sender: DataSender) -> Bool)?
    public var onClosed : (Void -> Void)?
    private var theStream : Stream
    
    public init(_ stream: Stream)
    {
        self.theStream = stream
    }
    
    public func pause() {
        theStream.clearReadyToWrite()
    }
    
    public func resume() {
        theStream.setReadyToWrite()
    }

    /**
     * Called when write error received.
     */
    public func receivedWriteError(error: ErrorType)
    {
        onError?(error: error)
    }
    
    /**
     * Called when the stream has data to be received.
     * receiver.read Can called by the consumer until data is left.
     */
    public func canSendData(sender: DataSender) -> Bool
    {
        if let onDataSendable = onDataSendable {
            return onDataSendable(sender: sender)
        }
        return false
    }
    
    /**
     * Called when the parent stream is closed.
     */
    public func streamClosed() {
        onClosed?()
    }
}


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

public class WSMessageReader
{
    private struct WSReadRequest
    {
        var message : WSMessage?
        var buffer : ReadBufferType
        var fully : Bool = false
        var length : LengthType
        var satisfied : LengthType = 0
        var callback : IOCallback?
        
        var remaining : LengthType
        {
            return length - satisfied
        }
    }
    
    /**
     * Information about the current frame being read
     */
    private var currentFrame = WSFrame()    
    private var controlFrameRequest = WSReadRequest(message: nil,
                                                    buffer: ReadBufferType.alloc(WSFrame.MAX_CONTROL_FRAME_SIZE),
                                                    fully: false,
                                                    length: WSFrame.MAX_CONTROL_FRAME_SIZE,
                                                    satisfied: 0, callback: nil)
    
    /**
     * Holds the outstanding read requests for each message as they are being read.
     * TODO: Make this a dictionary keyed by the channel and/or message id
     */
    private var readQueue = [WSReadRequest]()

    private var reader : WSFrameReader
    
    public init(_ reader: WSFrameReader)
    {
        self.reader = reader
    }

    public func startNextFrame()
    {
        // kick off the reading of the first frame
        self.reader.start { (frame, error) in
            if error == nil && frame != nil {
                self.currentFrame = frame!
                self.controlFrameRequest.satisfied = 0
                self.controlFrameRequest.length = self.currentFrame.payloadLength
                if self.controlFrameRequest.remaining == 0
                {
                    // we have the frame so process it and start the next frame
                    self.processCurrentFrame {
                        self.startNextFrame()
                    }
                } else {
                    self.continueReading()
                }
            } else {
                // TODO: close the connection
//                self.onClosedCallback?()
            }
        }
    }
    
    /**
     * Reads the body.  Here we can do a couple of things:
     * When a read is called, the reader can be either in "idle" state or in "reading header" state or in "reading payload" state
     * Here if a start is happening then we have to defer the "read" to when the start has finsished till we have data.
     * Once the reader is in "reading payload" state, we can have the following scenarios:
     * 1. The frame is a control frame, then just handle the frame and go back to reading again till the next two cases
     *    match.
     * 2. The frame belongs to a message that is new - so call the onMessage to begin handling of a new message 
     *    (this should get the message handler to start doing reads on the data which will come back through this path again)
     * 3. The frame belongs to an existing message (ie is a continuation):
     *    a. The message has outstanding read requests so serve it (and pop request off the queue)
     *    b. The message has no outstanding read requests.  At this point we can do two things:
     *       1. Buffer the data until we read frames corresponding to a message that has outstanding read requests.
     *          If there are no messages with read requests then dont buffer any data obviously.  Also if the buffer
     *          exceeds a particular threshold then the connection can just close with a 1009 response.
     *       2. Or just block until a read comes from the handler of this message and queues a read request.
     *          This is not a bad option since this way buffering can be done by the caller who may decide how much
     *          buffering to do (and in general buffer management can get messy).
     *
     * How to handle the first ever message?   When a connection is first created it has a stream from which reads 
     * and writes can be done.  This reader will be wrapped with a frame reader to return frames which is also nice.
     * However the frame reader will only be read from when a read on a message is invoked.  However a message cannot 
     * be created unless the frame reader has been read.   So a start on the frame reader has to be kicked off at some
     * time (or an intial read has to be kicked off) so that frames can start getting read and passed off to the message 
     * handlers for processing.   
     * 
     * One other scenario this can end up in is say if there are 5 messages being processed and neither of them have done a read yet
     * so on the connection there is a frame for a new message, since the read is not happening this new frame wont be read.
     *
     * Looks like both cases can be solved with a periodic read that happens in a loop (say every second or so as long as the 
     * read queue is empty)
     */
    public func read(message: WSMessage, buffer : ReadBufferType, length: LengthType, callback: IOCallback?)
    {
        // queue the request
        let newRequest = WSReadRequest(message: message, buffer: buffer, fully: false, length: length, satisfied: 0, callback: callback)
        readQueue.append(newRequest)
        continueReading()
    }
    
    private func continueReading()
    {
        // now see what to do based on the reader state
        // TODO: ensure a single loop/queue
        if reader.isIdle
        {
            // no frames have been read yet
            startNextFrame()
        }
        
        if reader.readingPayload
        {
            if readQueue.isEmpty && !self.currentFrame.isControlFrame
            {
                // then try again in a few milli seconds
                // TODO: Get the right runloop
                CoreFoundationRunLoop.currentRunLoop().enqueue({ () -> Void in
                    self.continueReading()
                })
            }

            // reading header so just queue the request
            // continue reading the current frame
            var currReadRequest = self.controlFrameRequest
            if !self.currentFrame.isControlFrame
            {
                // then pick the message corresponding to this frame
                if let readRequest = readQueue.first
                {
                    currReadRequest = readRequest
                }
                else
                {
                    // there is no read request corresponding to this message
                    // TODO: Block or Buffer?  If blocking then just return as the next
                    // continueReading will take care of this
                    assert(false, "Asserting to see how often and when this actually happens?")
                    return
                }
            }

            let currentBuffer = currReadRequest.buffer.advancedBy(currReadRequest.satisfied)
            let remaining = currReadRequest.remaining
            reader.read(currentBuffer, length: remaining, callback: { (length, error) in
                let endReached = IOErrorType.EndReached.equals(error)
                if error == nil || endReached
                {
                    if length > 0
                    {
                        currReadRequest.satisfied += length
                    }


                    if self.currentFrame.isControlFrame
                    {
                        // do nothing - wait till entire frame is processed
                        if currReadRequest.remaining == 0
                        {
                            // process the frame and start the next frame
                            self.processCurrentFrame {
                                self.startNextFrame()
                            }
                        } else {
                            // do nothing as the control frame must be read fully before being processed
                            self.continueReading()
                        }
                    } else {
                        self.readQueue.removeFirst()
                        currReadRequest.callback?(length: currReadRequest.satisfied, error: error)
                        if currReadRequest.remaining == 0
                        {
                            self.unwindWithError(IOErrorType.EndReached)
                            // and go on reading
                            self.continueReading()
                        }
                    }
                } else {
                    // we have an error so unwind all queued requests with this error a
                    // and close connection
                    self.unwindWithError(error!)
                }
            })
        }
    }
    
    /**
     * Process the current frame which is a control frame.
     * When processing is done call the callback if frame reading
     * is to be continued
     */
    private func processCurrentFrame(callback : Void -> Void)
    {
        if self.currentFrame.isControlFrame
        {
            // TODO: process the control frame
        } else {
            // no support for 0 length data frames yet
            assert(false, "Zero length data non-control frames not yet supported")
        }
        callback()
    }
    
    /**
     * Called when a read error occurred so all queued requests now need to be cancelled
     * with the error.
     */
    private func unwindWithError(error: ErrorType)
    {
        while !self.readQueue.isEmpty
        {
            if let next = self.readQueue.first
            {
                self.readQueue.removeFirst()
                next.callback?(length: next.satisfied, error: error)
            }
        }
    }
}
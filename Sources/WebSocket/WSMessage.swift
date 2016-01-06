//
//  WSMessage.swift
//  SwiftHTTP
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
    var messageType : WSFrame.Opcode = WSFrame.Opcode.ContinuationFrame
    
    /**
     * An user defined identifier associated with a message.
     */
    var messageId : String = ""
    
    public var identifier : String { get { return messageId } }

    public init(id : String)
    {
        messageId = id
    }

    public convenience init()
    {
        self.init(id: "")
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

public class WSMessageReader
{
    private var messageCounter = 0
    public typealias ClosedCallback = Void -> Void
    public typealias MessageCallback = (message: WSMessage) -> Void
    public var onMessage : MessageCallback?
    public var onClosed : ClosedCallback?

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
    
    /**
     * This method must always be called
     */
    public func start()
    {
        self.continueReading()
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
    
    /**
     * This method is the main "scheduler" loop of the reader.
     */
    private func continueReading()
    {
        // now see what to do based on the reader state
        // TODO: ensure a single loop/queue
        if reader.isIdle
        {
            // no frames have been read yet
            print("Message reader is idle.  Kicking off next frame")
            startNextFrame()
        }
        
        if reader.processingPayload
        {
            if readQueue.isEmpty && !self.currentFrame.isControlFrame
            {
                // then try again in a few milli seconds
                // TODO: Get the right runloop
                print("Read queue empty.  Dispatching again later on");
                CoreFoundationRunLoop.currentRunLoop().enqueueAfter(0.05) {
                    self.continueReading()
                }
                return
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
                    // This can mean two things:
                    // 1. This is a new frame (only if opcode != continuation) so this requires a new 
                    //    message to be created and called via the onMessage callback
                    // 2. An frame for a message that has already been called via the onMessage callback
                    //    but there are no outstanding read requests for it.  So this requires that
                    //    we either block until there is a request made for this message or buffer
                    //    this data and go forward.  For now we will block (as clients can do buffering
                    //    on their side anyway).
                    if self.currentFrame.isStartFrame
                    {
                        // clear the message queue with EndReached error as there is no more data
                        // on this message
                        self.unwindWithError(IOErrorType.EndReached)

                        self.processCurrentNewFrame(nil)
                    } else {
                        // otherwise just block and do a read later on
                    }
                    self.continueReading()
                    return
                }
            }

            let currentBuffer = currReadRequest.buffer.advancedBy(currReadRequest.satisfied)
            let remaining = currReadRequest.remaining
            reader.read(currentBuffer, length: remaining) { (length, error) in
                let endReached = (error as? IOErrorType) == IOErrorType.EndReached
                if error == nil || endReached
                {
                    assert(length >= 0, "Length cannot be negative")
                    currReadRequest.satisfied += length
                    if self.currentFrame.isControlFrame
                    {
                        // do nothing - wait till entire frame is processed
                        if currReadRequest.remaining == 0
                        {
                            // process the frame and start the next frame
                            self.processCurrentNewFrame {
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
            }
        }
    }
    
    private func startNextFrame()
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
                    self.processCurrentNewFrame {
                        self.startNextFrame()
                    }
                } else {
                    self.continueReading()
                }
            } else {
                self.onClosed?()
            }
        }
    }
    
    /**
     * This method will only be called when a control frame has
     * finished or if a non-control frame is of size 0
     */
    private func processCurrentNewFrame(callback : (Void -> Void)?)
    {
        if self.currentFrame.isControlFrame
        {
            // TODO: process the control frame
        } else {
            // ignore 0 length frames
            self.messageCounter += 1
            let newMessage = WSMessage(id: String(format: "%05d", self.messageCounter))
            newMessage.messageType = self.currentFrame.opcode
            // TODO: What should happen onMessage == nil?  Should it be allowed to be nil?
            self.onMessage?(message: newMessage)
        }
        callback?()
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

    private struct WSReadRequest
    {
        var message : WSMessage?
        var buffer : ReadBufferType
        var fully : Bool = false
        var length : LengthType
        var satisfied : LengthType = 0
        var callback : IOCallback?
        
        var remaining : LengthType { return length - satisfied }
    }
}

public class WSMessageWriter
{
    public typealias ClosedCallback = Void -> Void
    public var onClosed : ClosedCallback?

    /**
     * Frames wont be bigger than this
     */
    private var maxFrameSize : Int = DEFAULT_BUFFER_LENGTH
    
    /**
     */
    private var currMessageIndex = 0
    
    /**
     * Holds the outstanding read requests for each message as they are being read.
     * TODO: Make this a dictionary keyed by the channel and/or message id
     */
    private var writeQueue = [WSWriteRequest]()
    private var controlWriteQueue = [WSWriteRequest]()

    private var writer : WSFrameWriter
    
    public init(_ writer: WSFrameWriter, maxFrameSize: Int)
    {
        self.maxFrameSize = maxFrameSize
        self.writer = writer
    }
    
    public convenience init(_ writer: WSFrameWriter)
    {
        self.init(writer, maxFrameSize: DEFAULT_BUFFER_LENGTH)
    }

    public func write(opcode: WSFrame.Opcode, maskingKey: UInt32, source: Payload, callback: CompletionCallback?)
    {
        // queue the request
        let newRequest = WSWriteRequest(opcode: opcode, source: source, callback: callback)
        newRequest.maskingKey = maskingKey
        if opcode.isControlCode
        {
            controlWriteQueue.append(newRequest)
        } else {
            writeQueue.append(newRequest)
        }
        continueWriting()
    }
    
    /**
     * Writing messages is slightly simpler than reading messages.  With reading there was the problem of not
     * knowing when a message started and having to notify connection handlers on new messages so that *then*
     * they could initiate reads.
     *
     * With writes this problem does not exist.  ie a write can only be initiate by the connection handler and
     * each write marks the start of a new message.  How the message gets fragment is what this writer controls
     * in concert with the actual message source that is provided at the start of a write.
     *
     * So to prevent a front of line blocking of messages, round-robin (or with some other custom scheduling
     * technique) can be used to decide which message is to be sent in each write call.
     */
    private func continueWriting()
    {
        // only start a request if the writer is idle
        // (if it is already writing a frame then dont bother it)
        if writer.isIdle
        {
            if let nextWriteRequest = self.controlWriteQueue.first
            {
                sendNextFrame(nextWriteRequest)
            } else if let nextWriteRequest = self.writeQueue.first
            {
                sendNextFrame(nextWriteRequest)
            } else {
                // no requests left AND the writer is idle so try again later on
                // TODO: Get the right runloop
                print("Write queue empty.  Dispatching again later on")
                CoreFoundationRunLoop.currentRunLoop().enqueueAfter(0.05) {
                    self.continueWriting()
                }
            }
        }
    }
    
    private func sendNextFrame(writeRequest : WSWriteRequest)
    {
        writeRequest.writeNextFrame(writer, maxFrameSize: maxFrameSize) { (hasMore, error) -> Void in
            if error != nil
            {
                self.unwindWithError(error!)
            }
            else
            {
                if !hasMore
                {
                    // remove the request from the queue as it is done
                    if writeRequest.opcode.isControlCode
                    {
                        assert(self.controlWriteQueue.first === writeRequest)
                        self.controlWriteQueue.removeFirst()
                    } else
                    {
                        assert(self.writeQueue.first === writeRequest)
                        self.writeQueue.removeFirst()
                    }
                }
                self.continueWriting()
            }
        }
    }
    
    /**
     * Called when a read error occurred so all queued requests now need to be cancelled
     * with the error.
     */
    private func unwindWithError(error: ErrorType)
    {
        while let next = self.writeQueue.first
        {
            self.writeQueue.removeFirst()
            next.callback?(error: error)
        }
    }

    private class WSWriteRequest
    {
        /**
         * The source of the message.
         */
        var opcode: WSFrame.Opcode = WSFrame.Opcode(rawValue: 0)!
        var maskingKey: UInt32 = 0
        /**
         * The total length of the message as indicated by the payload.
         * If it does not exist then we fall back to the frame length
         * which is obtained by calling Payload.nextFrame()
         */
        var numFramesWritten = 0
        var hasTotalLength = false
        var currentLength : LengthType = 0
        var source : Payload
        var satisfied : LengthType = 0
        var callback : CompletionCallback?
        
        init(opcode: WSFrame.Opcode, source: Payload, callback: CompletionCallback?)
        {
            self.source = source
            self.opcode = opcode
            self.callback = callback
        }
        
        var remaining : LengthType {
            return currentLength > satisfied ? currentLength - satisfied : 0
        }
        
        func calculateLengths() -> Bool
        {
            if let totalLength = source.totalLength
            {
                hasTotalLength = true
                currentLength = LengthType(totalLength)
            } else if let currFrameLength = source.nextFrame()
            {
                hasTotalLength = false
                currentLength = LengthType(currFrameLength)
            } else {
                return false
            }
            return true
        }
        
        func writeNextFrame(writer: WSFrameWriter, maxFrameSize: Int, frameCallback : (hasMore : Bool, error : ErrorType?) -> Void)
        {
            assert(writer.isIdle, "Writer MUST be idle when this method is called.  Later on we could just skip this instead of asserting")
            // writer is idle so start the frame
            if currentLength == 0
            {
                // first time we are dealing with this frame so do a bit of book keeping
                if !calculateLengths()
                {
                    // this request is finished so call the callback and be done with it
                    callback?(error: nil)
                    frameCallback(hasMore: false, error: nil)
                }
            }
            let length = min(remaining, maxFrameSize)
            let isFirstFrame = numFramesWritten == 0
            let isFinalFrame = remaining <= maxFrameSize
            let realOpcode = isFirstFrame ? opcode : WSFrame.Opcode.ContinuationFrame
            writer.start(realOpcode, frameLength: length, isFinal: isFinalFrame, maskingKey: maskingKey) { (frame, error) -> Void in
                self.source.write(writer, length: length, completion: { (error) -> Void in
                    let endReached = (error as? IOErrorType) == IOErrorType.EndReached
                    if error == nil || endReached
                    {
                        self.satisfied += length
                        if self.remaining == 0
                        {
                            // first time we are dealing with this frame so do a bit of book keeping
                            if !self.calculateLengths()
                            {
                                // this request is finished so call the callback and be done with it
                                self.callback?(error: nil)
                                frameCallback(hasMore: false, error: nil)
                            }
                        } else
                        {
                            frameCallback(hasMore: true, error: nil)
                        }
                    } else {
                        frameCallback(hasMore: false, error: error)
                    }
                })
            }
        }
    }
}

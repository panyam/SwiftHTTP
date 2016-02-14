//
//  WSConnection.swift
//  SwiftHTTP
//
//  Created by Sriram Panyam on 12/30/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import SwiftIO

public typealias WSCallback = (message: WSMessage) -> Void

public protocol WSConnectionDelegate
{
    /**
     * Connection was closed.
     */
    func connectionClosed(connection: WSConnection)
}

public protocol WSConnectionHandler
{
    func handle(connection: WSConnection)
}

public class WSConnection
{
    public typealias ClosedCallback = Void -> Void
    public typealias MessageCallback = (message: WSMessage) -> Void

    var delegate : WSConnectionDelegate?
    private var frameReader: WSFrameReader
    private var frameWriter: WSFrameWriter

    public var onMessage : MessageCallback?
    public var onClosed : ClosedCallback?
    private var controlFrameBuffer : ReadBufferType = ReadBufferType.alloc(256)
    private var extensions = [WSExtension]()
    private var transportClosed = false
    
    public init(_ reader: Reader, writer: Writer, _ extensions: [WSExtension])
    {
        self.maxFrameWriteSize = DEFAULT_MAX_FRAME_SIZE
        self.frameReader = WSFrameReader(reader)
        self.frameWriter = WSFrameWriter(writer)
        self.extensions = extensions

        startReading()
    }
    
    private func handleClose() {
        self.connectionClosed()
    }

    private func handleMessage(message: WSMessage)
    {
        // TODO: What should happen onMessage == nil?  Should it be allowed to be nil?
        self.onMessage?(message: message)
    }
    
    /**
     * Called when a control frame has been read and needs to be handled.
     */
    private func handleControlFrame(frame: WSFrame, completion: CompletionCallback?)
    {
        if frame.reserved1Set || frame.reserved2Set || frame.reserved3Set
        {
            self.connectionClosed()
            completion?(error: nil)
        } else
        {
            self.frameReader.read(controlFrameBuffer, length: frame.payloadLength, fully: true) { (length, error) -> Void in
                if error != nil {
                    completion?(error: error)
                } else {
                    Log.debug("\n\nControl Frame \(frame.opcode) Length: \(frame.payloadLength)")
                    assert(frame.payloadLength == length, "Read fully didnt read fully!")
                    if frame.opcode == WSFrame.Opcode.CloseFrame
                    {
                        var source = BufferPayload(buffer: self.controlFrameBuffer, length: length)
                        if frame.payloadLength > 0 {
                            let code : UInt = ((UInt(self.controlFrameBuffer[0]) << 8) & 0xff00) | (UInt(self.controlFrameBuffer[1]) & 0xff)
                            if code < 1000 || (code >= 1004 && code <= 1006) || (code >= 1012 && code < 3000) || (code >= 5000){
                                // invalid close codes
                                let codeBuffer = ReadBufferType.alloc(2)
                                codeBuffer[0] = 0x03
                                codeBuffer[1] = 0xEA
                                source = BufferPayload(buffer: codeBuffer, length: 2)
                            }
                            else if length > 2 {
                                if let utf8String = NSString(data: NSData(bytes: self.controlFrameBuffer.advancedBy(2), length: length - 2), encoding: NSUTF8StringEncoding)
                                {
                                    Log.debug("Received UTF8 payload: \(utf8String)")
                                } else {
                                    let codeBuffer = ReadBufferType.alloc(2)
                                    codeBuffer[0] = 0x03
                                    codeBuffer[1] = 0xEA
                                    source = BufferPayload(buffer: codeBuffer, length: 2)
                                }
                            }
                        }
                        let replyCode = WSFrame.Opcode.CloseFrame
                        let message = self.startMessage(replyCode)
                        self.write(message, maskingKey: 0, source: source, isFinal: true, callback: completion)
                    }
                    else if frame.opcode == WSFrame.Opcode.PingFrame
                    {
                        let source = BufferPayload(buffer: self.controlFrameBuffer, length: length)
                        let replyCode = WSFrame.Opcode.PongFrame
                        let message = self.startMessage(replyCode)
                        self.write(message, maskingKey: 0, source: source, isFinal: true, callback: completion)
                    } else {
                        // ignore others (but finish their payloads off first)!
                        completion?(error: nil)
                    }
                }
            }
        }
    }
    
    private func connectionClosed()
    {
        self.delegate?.connectionClosed(self)
        self.onClosed?()
    }
    
    
    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //      All Message write related operations
    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    /**
    * Frames wont be bigger than this
    */
    private var maxFrameWriteSize : Int = DEFAULT_MAX_FRAME_SIZE
    private var currMessageCount = 0
    private var allMessages = [WSMessage]()
    private var currentWriteMessage : WSMessage?

    
    /**
    * Starts a new message tha
    t can be streamed out by the caller.
    * Once a message is created it can be written to continuosly.
    */
     
     /**
     * Starts a new message that can be streamed out by the caller.
     * Once a message is created it can be written to continuosly.
     */
    public func startMessage(opcode: WSFrame.Opcode) -> WSMessage
    {
        currMessageCount += 1
        let newMessage = WSMessage(type: opcode, id: String(format: "msg:%05d", currMessageCount))
        allMessages.append(newMessage)
        return newMessage
    }
    
    /**
     * Appends more data to a message.
     */
    public func write(message: WSMessage, maskingKey: UInt32, source: Payload, isFinal: Bool, callback: CompletionCallback?)
    {
        // queue the request
        if self.transportClosed
        {
            callback?(error: IOErrorType.Closed)
        } else {
            message.write(source, isFinal: isFinal, maskingKey: maskingKey, callback: callback)
            continueWriting()
        }
    }
    
    /**
     * Appends more data to a message.
     */
    public func write(message: WSMessage, source: Payload, isFinal: Bool, callback: CompletionCallback?)
    {
        write(message, maskingKey: 0, source: source, isFinal: isFinal, callback: callback)
    }
    
    /**
     * Appends more data to a message.
     */
    public func write(message: WSMessage, source: Payload, callback: CompletionCallback?)
    {
        write(message, maskingKey: 0, source: source, isFinal: false, callback: callback)
    }
    
    /**
     * Closes the message.  This message can no longer be written to.
     */
    public func closeMessage(message: WSMessage, callback: CompletionCallback?)
    {
        if self.transportClosed
        {
            callback?(error: IOErrorType.Closed)
        } else {
            message.close(callback)
        }
        self.continueReading()
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
        if frameWriter.isIdle
        {
            if currentWriteMessage != nil
            {
                sendNextFrame(currentWriteMessage!)
            } else {
                // pick a message which has messages
                for message in allMessages
                {
                    if !message.writeQueue.isEmpty
                    {
                        currentWriteMessage = message
                        continueWriting()
                        return
                    }
                }
            }
        }
    }
    
    private func sendNextFrame(message: WSMessage)
    {
        message.writeNextFrame(frameWriter, maxFrameSize: maxFrameWriteSize) { (writeRequest, error) -> Void in
            if error != nil
            {
                self.transportClosed = (error as? IOErrorType) == IOErrorType.Closed
                writeRequest?.callback?(error: error)
                self.unwindWritesWithError(message, error: error!)
            }
            else
            {
                if !message.hasMoreFrames
                {
                    self.currentWriteMessage = nil
                    assert(self.frameWriter.isIdle)
                }
                writeRequest?.callback?(error: error)
                self.continueWriting()
            }
        }
    }
    
    /**
     * Called when a read error occurred so all queued requests now need to be cancelled
     * with the error.
     */
    private func unwindWritesWithError(message: WSMessage, error: ErrorType)
    {
        Log.debug("Unwinding with error: \(error)")
        while let next = message.writeQueue.first
        {
            message.writeQueue.removeFirst()
            next.callback?(error: error)
        }
    }





    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    //      All Message read related operations
    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    public var validateUtf8 = true
    public var utf8Validator = Utf8Validator()
    private var messageCounter = 0
    
    /**
     * Information about the current message and frame being read
     * Only one frame can be read at a time.  It is upto the extensions
     * to demux these frames into messages across several channels
     */
    private var currentReadMessage : WSMessage?
    private var currentFrame = WSFrame()
    
    /**
     * Holds the outstanding read requests for each message as they are being read.
     * TODO: Make this a dictionary keyed by the channel and/or message id
     */
     //    private var readQueue = WSReadRequest()
    private var currentReadRequest : WSReadRequest?
    
    /**
     * This method must always be called
     */
    public func startReading()
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
    public func read(message: WSMessage, buffer : ReadBufferType, length: LengthType, fully: Bool, callback: WSMessageReadCallback?)
    {
        if transportClosed
        {
            callback?(length: 0, endReached: true, error: IOErrorType.Closed)
        } else {
            // queue the request
            assert(currentReadRequest == nil, "A read request is already running.  Make the request in a callback of another request or use promises")
            currentReadRequest = WSReadRequest(message: message, buffer: buffer, fully: fully, length: length, satisfied: 0, callback: callback)
            continueReading()
        }
    }
    
    private var frameReadStarted = false
    /**
     * This method is the main "scheduler" loop of the reader.
     */
    func continueReading()
    {
        // now see what to do based on the reader state
        // TODO: ensure a single loop/queue
        if frameReader.isIdle
        {
            // no frames have been read yet
            startReadingNextFrame()
        }
        
        // means we have started a frame, whether it is a control frame or not
        // someone will "read" it.  So if there are no read requests it means
        // there is eventually bound to be one
        if frameReader.processingPayload && currentReadRequest != nil && !frameReadStarted
        {
            assert(!frameReadStarted)
            frameReadStarted = true
            var theReadRequest = currentReadRequest!
            let currentBuffer = theReadRequest.buffer.advancedBy(theReadRequest.satisfied)
            let remaining = theReadRequest.remaining
            //            Log.debug("Message Reader Started reading next frame body, Type: \(self.currentFrame.opcode), Remaining: \(remaining)")
            frameReader.read(currentBuffer, length: remaining, fully: theReadRequest.fully) { (length, error) in
                self.frameReadStarted = false
                if error == nil
                {
                    assert(length >= 0, "Length cannot be negative")
                    theReadRequest.satisfied += length
                    if self.currentFrame.isControlFrame
                    {
                        // do nothing - wait till entire frame is processed
                        if theReadRequest.remaining == 0
                        {
                            // process the frame and start the next frame
                            self.startReadingNextFrame()
                        } else {
                            // do nothing as the control frame must be read fully before being processed
                            self.continueReading()
                        }
                    } else {
                        // so we have some data, pass this through all the extensions to see what can be done
                        // with it
                        for extn in self.extensions {
                            let (frame, error) = extn.newFrameRead(self.currentFrame)
                            if error != nil {
                                self.readerClosed()
                                return
                            }
                            self.currentFrame = frame
                        }

                        let endReached = self.frameReader.remaining == 0 && self.currentFrame.isFinal
                        if self.currentReadMessage!.messageType == WSFrame.Opcode.TextFrame && self.validateUtf8
                        {
                            let utf8Validated = self.utf8Validator.validate(currentBuffer, length) &&
                                (!endReached || self.utf8Validator.finish())
                            if !utf8Validated
                            {
                                self.readerClosed()
                                return
                            }
                        }
                        self.currentReadRequest = nil
                        if endReached
                        {
                            self.currentReadMessage = nil
                        }
                        theReadRequest.callback?(length: theReadRequest.satisfied, endReached: endReached, error: error)
                    }
                } else {
                    self.currentReadRequest = nil
                    self.currentReadMessage = nil
                    theReadRequest.callback?(length: 0, endReached: false, error: error)
                }
            }
        }
    }

    private func startReadingNextFrame()
    {
        // kick off the reading of the first frame
        //        Log.debug("Started reading next frame header, State: \(reader.state)")
        self.frameReader.start { (frame, error) in
            if error == nil && frame != nil {
                // we have the frame so process it and start the next frame
                self.processNewFrame(frame!) {(error) in
                    if !self.transportClosed
                    {
                        self.continueReading()
                    } else {
                        Log.debug("Transport closed")
                    }
                }
            } else {
                self.readerClosed()
            }
        }
    }
    
    private func readerClosed()
    {
        transportClosed = true
        self.onClosed?()
    }
    
    var frameCount = 0
    /**
     * This method will only be called when a control frame has
     * finished or if a non-control frame is of size 0
     */
    private func processNewFrame(frame: WSFrame, callback : CompletionCallback?)
    {
        frameCount += 1
        self.currentFrame = frame
        if self.currentFrame.isControlFrame
        {
            if !self.currentFrame.isFinal || self.currentFrame.payloadLength > 125 || frame.reserved1Set || frame.reserved2Set || frame.reserved3Set
            {
                // close the connection
                self.readerClosed()
            } else {
                self.handleControlFrame(self.currentFrame) {(error) in
                    if (self.currentFrame.opcode == WSFrame.Opcode.CloseFrame)
                    {
                        self.readerClosed()
                    } else {
                        callback?(error: error)
                    }
                }
            }
        } else {    // a non control frame
            // here get the frame through extensions
            for extn in extensions {
                let (frame, error) = extn.newFrameRead(self.currentFrame)
                if error != nil {
                    self.readerClosed()
                    return
                }
                self.currentFrame = frame
            }
            
            // after all extensions have gone through the frame, we cannot have reserved bits set
            if currentFrame.reserved1Set || currentFrame.reserved2Set || currentFrame.reserved3Set
            {
                // non 0 reserved bits without negotiated extensions
                // close the connection
                self.readerClosed()
            }
            else if self.currentFrame.opcode.isReserved
            {
                // close the connection
                self.readerClosed()
            } else if currentFrame.opcode == WSFrame.Opcode.ContinuationFrame {
                if currentReadMessage == nil
                {
                    self.readerClosed()
                } else {
                    callback?(error: nil)
                }
            } else {
                if currentReadMessage != nil
                {
                    // we already have a message so drop this
                    self.readerClosed()
                } else {
                    // starting a new message
                    self.utf8Validator.reset()
                    self.messageCounter += 1
                    let messageId = String(format: "%05d", self.messageCounter)
                    currentReadMessage = WSMessage(type: self.currentFrame.opcode, id: messageId)
                    self.handleMessage(currentReadMessage!)
                }
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
        var callback : WSMessageReadCallback?
        
        var remaining : LengthType { return length - satisfied }
    }
}


let READ_QUEUE_INTERVAL = 1.0
let WRITE_QUEUE_INTERVAL = 1.0
public let DEFAULT_MAX_FRAME_SIZE = DEFAULT_BUFFER_LENGTH

public typealias WSMessageReadCallback = (length: LengthType, endReached: Bool, error: ErrorType?) -> Void

public class WSMessage
{
    /**
     * Message type being sent
     */
    public var messageType : WSFrame.Opcode = WSFrame.Opcode.ContinuationFrame
    
    /**
     * An user defined identifier associated with a message.
     */
    var messageId : String = ""
    
    var totalFramesRead = 0
    var totalFramesWritten = 0
    
    /**
     * List of write requests on this message
     */
    var writeQueue = [WriteRequest]()
    
    public var identifier : String { get { return messageId } }
    
    public init(type: WSFrame.Opcode, id : String)
    {
        messageType = type
        messageId = id
    }
    
    public convenience init(type: WSFrame.Opcode)
    {
        self.init(type: type, id: "")
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
    
    public func write(source: Payload, isFinal: Bool, maskingKey: UInt32, callback: CompletionCallback?)
    {
        let newRequest = WriteRequest(source: source, callback: callback)
        newRequest.maskingKey = maskingKey
        newRequest.isFinalRequest = isFinal
        writeQueue.append(newRequest)
    }
    
    public func close(callback: CompletionCallback?)
    {
        //        assert(false, "Not yet implemented")
    }
    
    public var hasMoreFrames : Bool {
        return !writeQueue.isEmpty
    }
    
    class WriteRequest
    {
        /**
         * The source of the message.
         */
        var maskingKey: UInt32 = 0
        
        /**
         * The total length of the message as indicated by the payload.
         * If it does not exist then we fall back to the frame length
         * which is obtained by calling Payload.nextFrame()
         */
        var isFinalRequest = false
        var numFramesWritten = 0
        var hasTotalLength = false
        var currentLength : LengthType = 0
        var source : Payload
        var satisfied : LengthType = 0
        var callback : CompletionCallback?
        
        init(source: Payload, callback: CompletionCallback?)
        {
            self.source = source
            self.callback = callback
        }
        
        var remaining : LengthType {
            return currentLength > satisfied ? currentLength - satisfied : 0
        }
        
        func calculateLengths() -> Bool
        {
            if numFramesWritten == 0
            {
                if let totalLength = source.totalLength
                {
                    hasTotalLength = true
                    currentLength = LengthType(totalLength)
                    return true
                } else if let currFrameLength = source.nextFrame()
                {
                    hasTotalLength = false
                    currentLength = LengthType(currFrameLength)
                    return true
                }
            } else if !hasTotalLength {
                // should no longer calculate total Length
                if let currFrameLength = source.nextFrame()
                {
                    currentLength = LengthType(currFrameLength)
                    return true
                }
            }
            return false
        }
    }
    
    private func popWriteRequest(writeRequest : WriteRequest)
    {
        assert(self.writeQueue.isEmpty || self.writeQueue.first === writeRequest)
        if !self.writeQueue.isEmpty
        {
            self.writeQueue.removeFirst()
        }
    }
    
    func writeNextFrame(writer: WSFrameWriter, maxFrameSize: Int, frameCallback : (writeRequest: WriteRequest?, error: ErrorType?) -> Void)
    {
        assert(writer.isIdle, "Writer MUST be idle when this method is called.  Later on we could just skip this instead of asserting")
        
        // writer is idle so start the frame
        if let writeRequest = self.writeQueue.first
        {
            if writeRequest.currentLength == 0
            {
                // first time we are dealing with this frame so do a bit of book keeping
                if !writeRequest.calculateLengths()
                {
                    popWriteRequest(writeRequest)
                    frameCallback(writeRequest: writeRequest, error: nil)
                    return
                }
            }
            
            let length = min(writeRequest.remaining, maxFrameSize)
            let isFirstFrame = totalFramesWritten == 0
            let isFinalFrame = writeRequest.remaining <= maxFrameSize && writeRequest.isFinalRequest
            let realOpcode = isFirstFrame ? messageType : WSFrame.Opcode.ContinuationFrame
            //            Log.debug("Started writing next frame header: \(realOpcode), Length: \(length), isFinal: \(isFinalFrame)")
            writer.start(realOpcode, frameLength: length, isFinal: isFinalFrame, maskingKey: writeRequest.maskingKey) { (frame, error) in
                //                Log.debug("Finished writing next frame header: \(realOpcode), Length: \(length), isFinal: \(isFinalFrame)")
                if error != nil {
                    self.popWriteRequest(writeRequest)
                    frameCallback(writeRequest: writeRequest, error: error)
                    return
                }
                //                Log.debug("Started writing next frame body: \(realOpcode), Length: \(length), isFinal: \(isFinalFrame)")
                writeRequest.source.write(writer, length: length) { (error) in
                    //                    Log.debug("Finished writing next frame body: \(realOpcode), Length: \(length), isFinal: \(isFinalFrame)")
                    //                    Log.debug("-----------------------------------------------------------------------------------------------\n")
                    if error == nil
                    {
                        self.totalFramesWritten += 1
                        writeRequest.numFramesWritten += 1
                        writeRequest.satisfied += length
                        if writeRequest.remaining == 0
                        {
                            // first time we are dealing with this frame so do a bit of book keeping
                            if !writeRequest.calculateLengths()
                            {
                                self.popWriteRequest(writeRequest)
                                frameCallback(writeRequest: writeRequest, error: nil)
                                return
                            }
                        }
                    }
                    frameCallback(writeRequest: nil, error: error)
                }
            }
        }
    }
}

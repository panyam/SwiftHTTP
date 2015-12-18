
import SwiftIO

let CR : UInt8 = 13
let LF : UInt8 = 10
let BUFFER_LENGTH = 8192

public class HttpConnection // : Connection
{
    private enum ReadState : CFIndex {
        case READING_START_LINE
        case READING_HEADER_LINE
        case READING_REQUEST_BODY
    }

    public var delegate : HttpConnectionDelegate?

    private var socketStream : SocketStream?
    private var streamHandler : HttpStreamHandler?
    private var readState = ReadState.READING_START_LINE
    private var currentLine = ""
    private var currentRequest = HttpRequest()
    private var readBuffer = UnsafeMutablePointer<UInt8>.alloc(BUFFER_LENGTH)
    public var transport : ClientTransport?
    
    public init(socketStream : SocketStream)
    {
        self.socketStream = socketStream
        finishCurrentRequest()
    }

    /**
     * Called to initiate the closing of a connection.  Ensures that all data that is buffered is sent out
     * (as long as connection hasnt been called by the peer).
     */
    public func close()
    {
    }

    /**
     * Serves a new connection.
     */
    public func serve() {
    }

    private func parseStartLine(callback: (error : ErrorType) -> ()) {
    }

    /**
     * Finishes the current request and starts a new empty request.
     */
    public func finishCurrentRequest()
    {
        readState = ReadState.READING_START_LINE
        currentLine = ""
        currentRequest = HttpRequest()
    }
    
    /**
     * Called by the transport when it can pass data to be processed.
     * Returns a buffer (and length) into which at most length number bytes will be filled.
     */
    public func readDataRequested() -> (buffer: UnsafeMutablePointer<UInt8>, length: Int)?
    {
        return (readBuffer, BUFFER_LENGTH)
    }
    
    /**
     * Called to process data that has been received.
     * It is upto the caller of this interface to consume *all* the data
     * provided.
     */
    public func dataReceived(length: Int)
    {
        var currOffset = 0
        while currOffset < length {
            var numBytesProcessed = 0
            let prevState = readState
            switch readState {
            case .READING_START_LINE:
                numBytesProcessed = processStartLine(readBuffer, currOffset, length)
            case .READING_HEADER_LINE:
                numBytesProcessed = processHeaderLine(readBuffer, currOffset, length)
            case .READING_REQUEST_BODY:
                numBytesProcessed = streamHandler!.processData(readBuffer, currOffset, length)
            }

            assert(numBytesProcessed != 0, "At least one byte must have been processed or we have an error")
            if numBytesProcessed < 0 {
                // definitely error so stop, and close too
                return close()
            }
            
            currOffset += numBytesProcessed
            if prevState != readState && readState == ReadState.READING_REQUEST_BODY {
                // headers have finished so get the stream handler to do its thing
                streamHandler = delegate?.createStreamHandler(self, request: currentRequest)
                if streamHandler == nil {
                    // then try to guess it
                    streamHandler = createDefaultStreamHandler()
                    if streamHandler == nil {
                        // no stream handler found so close the request
                        return close()
                    }
                }
            }
        }
    }

    private func processStartLine(buffer: UnsafePointer<UInt8>, _ offset: Int, _ length: Int) -> Int
    {
        let (numBytesProcessed, foundLine) = processLine(buffer, offset, length)
        if foundLine {
            // parse the start line
            let parts = currentLine.componentsSeparatedByString(" ")
            currentRequest.method = parts[0]
            currentRequest.requestTarget = parts[1]
            if parts.count > 2 {
                currentRequest.version = parts[2]
            }
            
            delegate?.didReceiveRequest(self, method: parts[0], requestTarget: parts[1], version: parts[2])

            // clear currentLine for headers and set state
            readState = ReadState.READING_HEADER_LINE
            currentLine = ""
        }
        return numBytesProcessed
    }

    private func processHeaderLine(buffer: UnsafePointer<UInt8>, _ offset: Int, _ length: Int) -> Int
    {
        let (numBytesProcessed, foundLine) = processLine(buffer, offset, length)
        if foundLine {
            // parse the header line
            currentLine = currentLine.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            if let colIndex = currentLine.rangeOfString(":")?.startIndex
            {
                let headerKey = currentLine.substringToIndex(colIndex).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                let headerValue = currentLine.substringFromIndex(colIndex.advancedBy(1)).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                currentRequest.headerForKey(headerKey, create: true)?.addValue(headerValue)
                delegate?.didReceiveHeader(self, key: headerKey, value: headerValue)
            }
            else if currentLine == ""
            {
                // finished reading headers
                if !validateHeaders() {
                    return -1
                }
                delegate?.didReceiveHeaders(self)
                readState = ReadState.READING_REQUEST_BODY
            }

            // clear currentLine for next line
            currentLine = ""
        }
        return numBytesProcessed
    }
    
    private func processLine(buffer: UnsafePointer<UInt8>, _ offset: Int, _ length: Int) -> (Int, Bool)
    {
        for currOffset in offset..<length {
            let currChar = buffer[currOffset]
            if currChar == CR {
                if currOffset == length - 1 {
                    // we dont know if there is a LF after this
                    return (currOffset - offset, false)
                } else {
                    if buffer[currOffset + 1] == LF {
                        // yep LF found, so mark as found full line and consume CRLF
                        return ((currOffset - offset) + 2, true)
                    } else {
                        // append CR to it and go on
                        currentLine.append(Character(UnicodeScalar(currChar)))
                    }
                }
            } else {
                currentLine.append(Character(UnicodeScalar(currChar)))
            }
        }
        return (length - offset, false)
    }
    
    /**
     * Validates the headers in the current request.  
     * Returns true if validation succeeded, false otherwise.
     */
    private func validateHeaders() -> Bool
    {
        // TODO: Check target type
        // TODO: Check Host Headers
        return true;
    }
    
    public func createDefaultStreamHandler() -> HttpStreamHandler?
    {
        return Http1StreamHandler()
    }
}

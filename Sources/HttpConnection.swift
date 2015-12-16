
import SwiftSocketServer

let CR : UInt8 = 13
let LF : UInt8 = 10

class HttpConnection : Connection
{
    private enum ReadState : CFIndex {
        case READING_START_LINE
        case READING_HEADER_LINE
        case READING_REQUEST_BODY
    }

    var transport : ClientTransport?
    private var readState = ReadState.READING_START_LINE
    private var currentLine = ""
    private var currentRequest = HttpRequest()
    public var delegate : HttpConnectionDelegate?
    
    /**
     * Called when the connection has been closed.
     */
    func connectionClosed()
    {
        print("Good bye!")
    }

    /**
     * Called by the transport when it is ready to send data.
     * Returns the number of bytes of data available.
     */
    func writeDataRequested() -> (buffer: UnsafeMutablePointer<UInt8>, length: Int)?
    {
        print("Write data requested...");
//        return (buffer, length)
        return nil;
    }
    
    /**
     * Called into indicate numWritten bytes have been written.
     */
    func dataWritten(numWritten: Int)
    {
//        length -= numWritten
    }
    
    /**
     * Called to process data that has been received.
     * It is upto the caller of this interface to consume *all* the data
     * provided.
     */
    func dataReceived(buffer: UnsafePointer<UInt8>, length: Int)
    {
        processData(buffer, 0, length)
    }

    private func processData(buffer: UnsafePointer<UInt8>, _ offset: Int, _ length: Int)
    {
        var currOffset = offset
        while currOffset < length {
            var numBytesProcessed = 0
            let currState = readState
            switch readState {
            case .READING_START_LINE: numBytesProcessed = processStartLine(buffer, currOffset, length)
            case .READING_HEADER_LINE: numBytesProcessed = processHeaderLine(buffer, currOffset, length)
            case .READING_REQUEST_BODY: numBytesProcessed = processRequestBody(buffer, currOffset, length)
            }
            if numBytesProcessed == 0 {
                // state MUST have changed otherwise
                assert(currState != readState, "With 0 bytes processed, states MUST have changed")
            } else if numBytesProcessed < 0 {
                // definitely error
            } else {
                currOffset += numBytesProcessed
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
            if currentLine == ""
            {
                // finished reading headers
                delegate?.didReceiveHeaders(self)
                readState = ReadState.READING_REQUEST_BODY
            }
            else if let colIndex = currentLine.rangeOfString(":")?.startIndex
            {
                let headerKey = currentLine.substringToIndex(colIndex).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                let headerValue = currentLine.substringFromIndex(colIndex.advancedBy(1)).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
                currentRequest.headerForKey(headerKey, create: true)?.addValue(headerValue)
                delegate?.didReceiveHeader(self, key: headerKey, value: headerValue)
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
    
    private func processRequestBody(buffer: UnsafePointer<UInt8>, _ offset: Int, _ length: Int) -> Int
    {
        return 0
    }
}
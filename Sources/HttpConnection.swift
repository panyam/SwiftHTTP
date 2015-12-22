
import SwiftIO

let CR : UInt8 = 13
let LF : UInt8 = 10
let CRLF : String = "\0d0a"
let BUFFER_LENGTH = 8192

public class HttpConnection // : Connection
{
    public var delegate : HttpConnectionDelegate?

    private var socketStream : SocketStream?
    private var streamHandler : HttpStreamHandler?
    private var currentRequest = HttpRequest()
    private var readBuffer = UnsafeMutablePointer<UInt8>.alloc(BUFFER_LENGTH)
    private var buffReader : BufferedReader
    public var transport : ClientTransport?
    
    public init(socketStream : SocketStream)
    {
        self.socketStream = socketStream
        buffReader = BufferedReader(reader: socketStream, bufferSize: BUFFER_LENGTH)
    }

    /**
     * Finishes the current request and starts a new empty request.
     */
    public func finishCurrentRequest()
    {
        currentRequest = HttpRequest()
    }
    
    /**
     * Serves a new connection.
     */
    public func serve() {
        finishCurrentRequest()

        parseStartLineAndHeaders { (error) -> () in
            // ready to read body and handle it!
        }
    }
    
    private func parseStartLineAndHeaders(callback: (error : ErrorType?) -> ())
    {
        buffReader.readTillChar(LF) { (str, error) -> () in
            if error != nil {
                callback(error: error)
            } else {
                self.parseStartLine(str)
                
                // now read headers
                self.processHeaders(callback)
            }
        }
    }
    
    private func parseStartLine(startLine: String)
    {
        // parse the start line
        let parts = startLine.componentsSeparatedByString(" ")
        currentRequest.method = parts[0]
        currentRequest.requestTarget = parts[1]
        if parts.count > 2 {
            currentRequest.version = parts[2]
        }
        
        delegate?.didStartNewRequest(self, method: parts[0], requestTarget: parts[1], version: parts[2])
    }
    
    private func processHeaders(callback: (error: ErrorType?) -> ())
    {
        buffReader.readTillChar(LF) { (str, error) -> () in
            if error != nil {
                callback(error: error)
                return
            }
            
            let finished = self.parseHeaderLine(str)
            if finished {
                // finished reading headers
                if !self.validateHeaders() {
                    callback(error: nil)
                } else {
                    self.delegate?.didReceiveHeaders(self)
                    
                    // now the next bit
                    callback(error: nil)
                }
            } else {
                self.processHeaders(callback)
            }
        }
    }
    
    private func parseHeaderLine(line: String) -> (Bool)
    {
        // parse the header line
        let currentLine = line.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
        if currentLine == ""
        {
            return true
        }

        if let colIndex = currentLine.rangeOfString(":")?.startIndex
        {
            let headerKey = currentLine.substringToIndex(colIndex).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            let headerValue = currentLine.substringFromIndex(colIndex.advancedBy(1)).stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
            currentRequest.headerForKey(headerKey, create: true)?.addValue(headerValue)
            delegate?.didReceiveHeader(self, key: headerKey, value: headerValue)
        }
        return false
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

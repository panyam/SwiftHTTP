
import SwiftIO

let CR : UInt8 = 13
let LF : UInt8 = 10
let CRLF : String = "\r\n"

public class HttpConnection : HttpResponseDelegate
{
    public var delegate : HttpConnectionDelegate?

    private var writer : Writer
    private var buffReader : BufferedReader
    private var currentRequestHandler : HttpRequestHandler?
    private var currentRequest = HttpRequest()
    private var currentResponse : HttpResponse?
    
    public init(reader: Reader, writer: Writer)
    {
        self.writer = writer
        self.buffReader = BufferedReader(reader)
    }

    /**
     * Serves a new connection.
     */
    public func serve() {
        currentRequest = HttpRequest()

        parseStartLineAndHeaders { (error) -> () in
            // ready to read body and handle it!
            print("Headers received...")
            self.currentRequestHandler = self.delegate?.createRequestHandler(self, request: self.currentRequest)
            if self.currentRequestHandler == nil {
                self.currentRequestHandler = self.createDefaultRequestHandler()
            }
            self.currentRequestHandler!.handleRequest(self.currentRequest, response: self.currentResponse!)
        }
    }
    
    private func parseStartLineAndHeaders(callback: (error : ErrorType?) -> ())
    {
        buffReader.readTillChar(LF) { (str, error) -> () in
            if error != nil {
                return callback(error: error)
            }

            self.parseStartLine(str)
            
            // now read headers
            self.processHeaders(callback)
        }
    }
    
    private func parseStartLine(startLine: String)
    {
        // parse the start line
        let parts = startLine.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).componentsSeparatedByString(" ")
        currentRequest.method = parts[0]
        currentRequest.requestTarget = parts[1]
        if parts.count > 2 {
            currentRequest.version = parts[2]
        }
        
        currentResponse = HttpResponse(version: currentRequest.version)
        currentResponse!.delegate = self
        currentResponse!.setWriter(writer)

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
            currentRequest.headers.forKey(headerKey, create: true)?.addValue(headerValue)
            delegate?.didReceiveHeader(self, key: headerKey, value: headerValue)
        } else {
            // TODO: ignore or reject bad header lines?
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
    
    public func createDefaultRequestHandler() -> HttpRequestHandler?
    {
        return Http1RequestHandler()
    }
    
    // HttpResponseDelegate methods
    /**
    * Called after the headers for a response have been written
    */
    public func headersWritten(response: HttpResponse)
    {
    }
    
    /**
     * Called after the body of the response has been written and no more bytes can be written.
     * Essentially the request handling is complete
     */
    public func bodyWritten(response: HttpResponse)
    {
        // TODO: close connection if necessary or start serving of a new one
        if currentRequest.version.lowercaseString == "http/1.0" ||
            currentRequest.headers.forKey("Connection")?.firstValue()?.lowercaseString == "close" {
//            buffReader.stream.close()
        } else {
            self.serve()
//            let currRunLoop = CFRunLoopGetCurrent()
//            CFRunLoopPerformBlock(currRunLoop, kCFRunLoopCommonModes) { () -> Void in
//            }
//            CFRunLoopWakeUp(currRunLoop)
        }
    }
}

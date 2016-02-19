
import SwiftIO
import RxSwift

let CR : UInt8 = 13
let LF : UInt8 = 10
let CRLF : String = "\r\n"

public typealias HttpRequestHandler = (request: HttpRequest, response: HttpResponse) -> Void

public protocol HttpConnectionDelegate
{
    func connectionFinished(connection: HttpConnection)
}

public class HttpConnection : HttpResponseDelegate
{
    /**
     * An identifier for debugging purposes
     */
    public var identifier : String = ""
    
    var delegate : HttpConnectionDelegate?
    private var theWriter : Writer
    private var theReader : BufferedReader
    public var requestHandler : HttpRequestHandler?
    private var currentRequest = HttpRequest(nil)
    private var currentResponse = HttpResponse(nil)
    
    public var writer : Writer { get { return theWriter } }
    public var reader : Reader { get { return theReader } }
    
    public init(reader: Reader, writer: Writer)
    {
        self.theWriter = writer
        self.theReader = BufferedReader(reader)
    }

    /**
     * Serves a new connection.
     * Returns an Observable<HttpRequest>
     */
    public func serve() -> Observable<HttpRequest>
    {
        Observable.gene
        currentRequest = HttpRequest(self)
        currentResponse = HttpResponse(self)
        return Observable.create { (observer : AnyObserver<HttpRequest>) -> Disposable in
            // keep reading bytes and aggregating them into lines
            // keep reading lines and aggregating them into a header collection
            // once all headers are received we have a new request
            self.parseStartLineAndHeaders { (error) -> () in
                // ready to read body and handle it!
                Log.debug("Connection: \(self.identifier)")
                Log.debug("Headers: \(self.currentRequest)")
                observer.onNext(self.currentRequest)
            }
            return AnonymousDisposable({})
        }
    }

    private func parseStartLineAndHeaders(callback: CompletionCallback)
    {
        reader.readTillChar(LF) { (str, error) -> Void in
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
        
        currentResponse.setVersion(currentRequest.version)
        currentResponse.delegate = self
        currentResponse.setWriter(writer)
    }
    
    private func processHeaders(callback: (error: ErrorType?) -> ())
    {
        reader.readTillChar(LF) { (str, error) -> Void in
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
    
    /**
     * Called after the body of the response has been written and no more bytes can be written.
     * Essentially the request handling is complete
     */
    public func bodyWritten(response: HttpResponse, error: ErrorType?)
    {
        // TODO: close connection if necessary or start serving of a new one
        if error != nil ||
            currentRequest.version.lowercaseString == "http/1.0" ||
            currentRequest.headers.forKey("Connection")?.firstValue()?.lowercaseString == "close"
        {
            self.delegate?.connectionFinished(self)
        }
        else {
            self.consumeCurrentRequest()
            self.serve()
        }
    }
    
    // TODO: ensure that the entire body of the current request has been read
    // before starting the next request - part of RFC 2616
    // One thing to be careful is to place some upper limit on how big this 
    // can be so it doesnt open up the server to getting DDOSed
    private func consumeCurrentRequest()
    {
    }
}

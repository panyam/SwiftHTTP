
import SwiftIO

public protocol HttpResponseDelegate
{
    /**
     * Called after the body of the response has been written and no more bytes can be written. 
     * Essentially the request handling is complete
     */
    func bodyWritten(response: HttpResponse, error: ErrorType?)
}

public class HttpResponse : HttpMessage, CustomStringConvertible {
    private(set) var statusCode = HttpStatusCode.Ok.rawValue
    private(set) var httpVersion = ""
    private(set) var reasonPhrase = "OK"
    private(set) var writer: Writer?
    private(set) var body: HttpBody?
    var delegate: HttpResponseDelegate?
    
    // Have headers been written
    private var writtenHeaders = false
    
    public override func reset()
    {
        super.reset()
        writtenHeaders = false
    }
    
    public var description : String {
        return "\(httpVersion) \(statusCode) \(reasonPhrase)\(CRLF)\(headers)"
    }

    public func setVersion(version: String)
    {
        self.httpVersion = version
    }
    
    public func setWriter(writer: Writer)
    {
        self.writer = writer
    }

    public func setBody(body: HttpBody)
    {
        self.body = body
    }

    public func setStatus(code: HttpStatusCode)
    {
        setStatus(code.rawValue, nil)
    }
    
    public func setStatus(code: Int)
    {
        setStatus(code, nil)
    }
    
    public func setStatus(code: Int, _ reason: String?)
    {
        // do not allow change if headers have not yet been written
        if !writtenHeaders
        {
            statusCode = code
            reasonPhrase = "No Reason"
            if let phrase = reason
            {
                reasonPhrase = phrase
            }
            else if let statusCode = HttpStatusCode(rawValue: code)
            {
                reasonPhrase = statusCode.reasonPhrase()!
            }
        }
    }

    /**
     * Closes the responses and flushes any outstanding data.
     * Either this method can be called or writeHeaders and writeBody can be called 
     * manually.
     */
    public func close()
    {
        writeHeaders()

        // now write the body if any
        if self.body == nil {
//            self.delegate?.bodyWritten(self)
        }
        else if let writer = self.writer
        {
            self.body?.write(writer, length: 0) { (error) -> () in
                // TODO: Have a CappedWriter in place to ensure no more than totalLength number of bytes have been written.
                // TODO: Ensure chunked encoding
                // TODO: Do framing of data if required
                Log.debug("Response written")
                self.delegate?.bodyWritten(self, error: error)
            }
        }
    }
    
    public func writeHeaders()
    {
        if !writtenHeaders {
            writtenHeaders = true
            // see if content length was set and if not, does it need to be set?
            if body == nil
            {
                // set content length to 0
                headers.setValueFor("Content-Length", value: "0")
                headers.remove("Transfer-Encoding")
            }
            else
            {
                if let _ = headers.forKey("Content-Length", create: false) {
                    // if a content length was provided then remove the transfer encoding
                    headers.remove("Transfer-Encoding")
                }
                else if let contentLength = body?.totalLength {
                    headers.setValueFor("Content-Length", value: String(format: "%d", contentLength))
                    
                    // remove TransferEncoding header as content length is known
                    headers.remove("Transfer-Encoding")
                }
                
                // give the body writer a chance to massage the response
                body!.decorateResponse(self)
            }
            
            // write the status line first
            Log.debug("===============================")
            Log.debug("Writing headers for connection: \(connection?.identifier)")
            if let writer = self.writer
            {
                Log.debug("\(headers)")
                writer.writeString("\(httpVersion) \(statusCode) \(reasonPhrase)\(CRLF)")
                writer.writeString(headers.description)
                writer.writeString(CRLF)
            }
        }
    }
}

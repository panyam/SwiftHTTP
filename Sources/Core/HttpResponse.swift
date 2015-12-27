
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
    private(set) var statusCode = 200
    private(set) var httpVersion = ""
    private(set) var reasonPhrase = "OK"
    private(set) var writer: Writer?
    private(set) var bodyWriter: HttpBodyWriter?
    var delegate: HttpResponseDelegate?
    
    // Have headers been written
    private var writtenHeaders = false
    
    public var description : String {
        return "\(httpVersion) \(statusCode) \(reasonPhrase)\(CRLF)\(headers)"
    }

    public init(version: String) {
        httpVersion = version
    }

    public func setWriter(writer: Writer)
    {
        self.writer = writer
    }

    public func setBodyWriter(bodyWriter: HttpBodyWriter)
    {
        self.bodyWriter = bodyWriter
    }
    
    public func setStatus(code: Int, _ reason: String?)
    {
        // do not allow change if headers have not yet been written
        if !writtenHeaders
        {
            statusCode = code
            if let phrase = reason
            {
                reasonPhrase = phrase
            } else {
                reasonPhrase = HttpResponse.defaultReasonPhrase(statusCode)
            }
        }
    }
    
    public static func defaultReasonPhrase(code: Int) -> String
    {
        // TODO: find the default reason phrase for the given code
        return "OK"
    }

    /**
     * Closes the responses and flushes any outstanding data.
     */
    public func close()
    {
        flushHeaders()

        // now write the body if any
        if self.bodyWriter == nil {
//            self.delegate?.bodyWritten(self)
        }
        else if let writer = self.writer
        {
            self.bodyWriter?.write(writer, callback: { (numWritten, error) -> () in
                print("Response written")
                self.delegate?.bodyWritten(self, error: error)
            })
        }
    }
    
    private func flushHeaders()
    {
        if !writtenHeaders {
            writtenHeaders = true
            // see if content length was set and if not, does it need to be set?
            if bodyWriter == nil
            {
                // set content length to 0
                headers.forKey("Content-Length", create: true)?.setValue("0")
                headers.removeHeader("Transfer-Encoding")
            }
            else
            {
                if let _ = headers.forKey("Content-Length", create: false) {
                    // if a content length was provided then remove the transfer encoding
                    headers.removeHeader("Transfer-Encoding")
                }
                else if let cl = bodyWriter?.contentLength() {
                    headers.forKey("Content-Length", create: true)?.setValue(String(format: "%d", cl))
                    
                    // remove TransferEncoding header as content length is known
                    headers.removeHeader("Transfer-Encoding")
                }
                
                // give the body writer a chance to massage the response
                bodyWriter!.decorateResponse(self)
            }
            
            // write the status line first
            if let writer = self.writer
            {
                writer.writeString("\(httpVersion) \(statusCode) \(reasonPhrase)\(CRLF)")
                writer.writeString(headers.description)
                writer.writeString(CRLF)
            }
        }
    }
}

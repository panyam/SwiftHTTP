
import SwiftIO

public class HttpResponse : HttpMessage {
    private(set) var statusCode = 200
    private(set) var httpVersion = ""
    private(set) var reasonPhrase = "OK"
    private(set) var writer: Writer?
    
    public init(version: String) {
        httpVersion = version
    }

    public func setWriter(weak writer: Writer)
    {
        self.writer = writer
    }

    public func setStatus(code: Int, _ reason: String?)
    {
        statusCode = code
        if let phrase = reason
        {
            reasonPhrase = phrase
        } else {
            reasonPhrase = HttpResponse.defaultReasonPhrase(statusCode)
        }
    }
    
    public static func defaultReasonPhrase(code: Int) -> String
    {
        // TODO: find the default reason phrase for the given code
        return "OK"
    }
}

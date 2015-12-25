
import SwiftIO

public class HttpRequest : HttpMessage, CustomStringConvertible {
    var method = "GET"
    var requestTarget = ""
    var version = "HTTP 1.1"
    var reader : BufferedReader?
    
    public var description : String {
        return "\(method) \(requestTarget) \(version)\(CRLF)\(headers)"
    }
}

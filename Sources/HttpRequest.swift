
import SwiftIO

public class HttpRequest : HttpMessage {
    var method = "GET"
    var requestTarget = ""
    var version = "HTTP 1.1"
    var reader : BufferedReader?
}

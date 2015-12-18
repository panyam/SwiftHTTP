
import SwiftIO

public class HttpResponse : HttpMessage {
    var statusCode = 200
    var httpVersion = ""
    var reasonPhrase = "OK"
    var outputStream: Writer?
}

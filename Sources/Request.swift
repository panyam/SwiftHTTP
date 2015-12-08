
public class HttpRequest : HttpMessage {
    var method = "GET"
    var inputStream: Reader?

    init(method: String) {
        self.method = method
    }
}

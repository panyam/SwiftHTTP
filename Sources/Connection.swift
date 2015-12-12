

public class HttpConnection {
    var inputStream: Reader?
    var outputStream: Writer?

    init(input: Reader?, output: Writer?) {
        inputStream = input
        outputStream = output
    }

    func start() {
        // Starts the connection handling
        // while more requests available
        //      Read requets headers
        //      Find processor for request based on headers (eg 1.0, 1.1, websocket, 2.0 etc)
        //      processor.handle(inputStream, outputStream)
    }
}


import SwiftIO
import SwiftHTTP

let MESSAGE_READ_SIZE = DEFAULT_MAX_FRAME_SIZE

public extension WSMessage
{
    public var readBuffer : ReadBufferType
    {
        get
        {
            if extraData("buffer") == nil
            {
                let buffer = ReadBufferType.alloc(MESSAGE_READ_SIZE)
                setExtraData("buffer", value: buffer)
            }
            return extraData("buffer") as! ReadBufferType
        }
    }
}

public class WSEchoHandler : WSConnectionHandler
{
    var connection : WSConnection?
    
    // Handles a new connection
    public func handle(connection: WSConnection)
    {
        self.connection = connection
        connection.onMessage = self.processMessage
        connection.onClosed = self.connectionClosed
    }
    
    private func connectionClosed()
    {
        // called when connection will be closed as soon as this handler returns
        // note that calls to connection.sendMessage or connection.readMessage
        // will do nothing (and their callbacks wont be called)
    }
    
    private func processMessage(message: WSMessage)
    {
        let buffer = message.readBuffer
        if message.extraData("response") == nil
        {
            let response = connection?.startMessage(message.messageType)
            message.setExtraData("response", value: response)
        }
        let response = message.extraData("response") as! WSMessage

        connection?.read(message, buffer: buffer, length: MESSAGE_READ_SIZE, fully: false) {(length, endReached, error) in
            if error == nil
            {
                let source = BufferPayload(buffer: buffer, length: length)
                self.connection?.write(response, source: source, isFinal: endReached) { (error) in
                    if error == nil && length > 0 {
                        // process message by doing more reads on the message
                        // or call message.discard() to discard the rest of the
                        // message
                        self.processMessage(message)
                    } else {
                        // no more data here so this message is complete -
                        // any more reads on this message wont return anything
                        // (and the callback want be called so dont call it)
                        self.connection?.closeMessage(response) {(error) in
                        }
                    }
                }
            } else
            {
                // some other error happened
            }
        }
    }
}

func testWSServer()
{
    let server = HttpServer(9001)
    
    let wsHandler = WSEchoHandler()
    server.serve(WSRequestServer(wsHandler))

    // This has to be started
    CoreFoundationRunLoop.defaultRunLoop().start()
}

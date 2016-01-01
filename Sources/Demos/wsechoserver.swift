
import SwiftIO

public class WSEchoHandler : WSConnectionHandler
{
    let MESSAGE_READ_SIZE = 256
    var reader : StatefulReader?
    var connection : WSConnection?
    
    // Handles a new connection
    public func handle(connection: WSConnection)
    {
        self.connection = connection
        connection.onMessage(self.processMessage)
        connection.onClosed(self.connectionClosed)
    }
    
    private func connectionClosed()
    {
        // called when connection will be closed as soon as this handler returns
        // note that calls to connection.sendMessage or connection.readMessage
        // will do nothing (and their callbacks wont be called)
    }
    
    private func processMessage(message: WSMessage)
    {
        if message.extraData("buffer") == nil
        {
            let buffer = ReadBufferType.alloc(MESSAGE_READ_SIZE)
            message.setExtraData("buffer", value: buffer)
        }
        let buffer = message.extraData("buffer") as! ReadBufferType

        message.read(buffer, length: MESSAGE_READ_SIZE) {(length: Int, error: ErrorType?) in
            let endReached = IOErrorType.EndReached.equals(error)
            if error == nil || endReached
            {
                // process the data received so far by just echoing it out
                let source = BufferPayload(buffer: buffer, length: length)
                self.connection?.sendMessage(message.messageType, maskingKey: 0, source: source, callback: { (message) -> Void in
                    if !endReached {
                        // process message by doing more reads on the message
                        // or call message.discard() to discard the rest of the
                        // message
                        self.processMessage(message)
                    } else {
                        // no more data here so this message is complete -
                        // any more reads on this message wont return anything
                        // (and the callback want be called so dont call it)
                    }
                })
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

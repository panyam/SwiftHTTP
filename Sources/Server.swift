
protocol Connection {
}

protocol ConnectionHandler {
    func handleConnection(connection: Connection)
}

protocol ServerTransport {
    var connectionHandler : ConnectionHandler? { get set }
    func start()
    func stop()
}

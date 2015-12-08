
enum StreamError {
}

protocol Seekable {
    func seek(position: Int)
}

protocol Closeable {
    func close()
}

protocol Reader {
    func read(length: Int, buffer: [Int8], callback: (numRead: Int, error: StreamError))
}

protocol Writer {
    func write(length: Int, buffer: [Int8], callback: (numRead: Int, error: StreamError))
}


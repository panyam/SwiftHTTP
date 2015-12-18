
enum StreamError {
}

protocol Seekable {
    func seek(position: Int)
}

protocol Closeable {
    func close()
}

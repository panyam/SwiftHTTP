
public class HttpMessage {
    var headers: [String: Header]
    
    init() {
        headers = [String: Header]()
    }
    
    public func headerForKey(key: String, create: Bool) -> Header? {
        if let header = headers[key] {
            return header
        }
        if create {
            headers[key] = Header()
        }
        return nil
    }
}

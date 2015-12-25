
public class HeaderCollection : CustomStringConvertible
{
    private var headers = [String: Header]()
    
    public init()
    {
    }
    
    public func forKey(key: String) -> Header? {
        return forKey(key, create: false)
    }
    
    public func forKey(key: String, create: Bool) -> Header? {
        if let header = headers[key] {
            return header
        }
        if create {
            headers[key] = Header(name: key)
        }
        return headers[key]
    }
    
    public func removeHeader(key: String)
    {
        headers.removeValueForKey(key)
    }
    
    public var description : String {
        var out : String = ""
        // write the headers
        for (headerKey, header) in headers
        {
            for value in header.values {
                out.appendContentsOf("\(headerKey): \(value) \(CRLF)")
            }
        }
        return out
    }
}

public class HttpMessage {
    var headers = HeaderCollection()

    public init() {
    }
}

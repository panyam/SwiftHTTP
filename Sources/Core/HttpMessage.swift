

public class StringMultiMap
{
    private var headers = [String: Header]()
    
    /**
     * Return the header for a particular key.
     */
    public func forKey(key: String) -> Header? {
        return forKey(key, create: false)
    }
    
    /**
     * Return the header for a particular key and optionally create it if it does not exist
     */
    public func forKey(key: String, create: Bool) -> Header? {
        if let header = headers[key] {
            return header
        }
        if create {
            headers[key] = Header(name: key)
        }
        return headers[key]
    }
    
    /**
     * Removes all values for a header by the given name.
     */
    public func removeHeader(key: String)
    {
        headers.removeValueForKey(key)
    }
}

/**
 * A simple collection of headers along with their values.
 */
public class HeaderCollection : StringMultiMap, CustomStringConvertible
{
    /**
     * Custom description of this header collection.
     */
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

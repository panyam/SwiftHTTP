

public class StringMultiMap
{
    private var dictionary = [String: Header]()
    private var caseSensitiveKeys : Bool = false
    
    public init(caseSensitiveKeys: Bool)
    {
        self.caseSensitiveKeys = caseSensitiveKeys
    }
    
    private func normalizedKey(key: String) -> String
    {
        return caseSensitiveKeys ? key : key.lowercaseString
    }
    
    /**
     * Return the header for a particular key.
     */
    public func forKey(key: String) -> Header? {
        return forKey(key, create: false)
    }
    
    /**
     * Removes all entries
     */
    public func removeAll()
    {
        dictionary.removeAll()
    }
    
    /**
     * Return the header for a particular key and optionally create it if it does not exist
     */
    public func forKey(key: String, create: Bool) -> Header? {
        let normKey = normalizedKey(key)
        if let header = dictionary[normKey] {
            return header
        }
        if create {
            dictionary[normKey] = Header(name: key)
        }
        return dictionary[normKey]
    }
    
    /**
     * Removes all values for a header by the given name.
     */
    public func remove(key: String)
    {
        dictionary.removeValueForKey(normalizedKey(key))
    }
    
    /**
     * Returns true if a header with a particular key exists
     */
    public func containsKey(key: String) -> Bool
    {
        return dictionary[normalizedKey(key)] != nil
    }
    
    public func firstValueFor(key: String) -> String?
    {
        return self.forKey(key)?.firstValue()
    }
    
    public func setValueFor(key: String, value: String?)
    {
        if let v = value {
            forKey(key, create: true)?.setValue(v)
        } else {
            remove(key)
        }
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
        for (headerKey, header) in dictionary
        {
            for value in header.values {
                out.appendContentsOf("\(headerKey): \(value) \(CRLF)")
            }
        }
        return out
    }
}

public class HttpMessage {
    var headers = HeaderCollection(caseSensitiveKeys: false)
    public init() {
    }
    
    public var hostHeader : String? {
        get
        {
            return headers.firstValueFor("Host")
        }
        set (value)
        {
            headers.setValueFor("Host", value: value)
        }
    }
    
    public var connectionHeader : String? {
        get
        {
            return headers.firstValueFor("Connection")
        }
        set (value)
        {
            headers.setValueFor("Connection", value: value)
        }
    }
    
    var extraDataDict = [String : Any]()
    public func extraData(key: String) -> Any?
    {
        return extraDataDict[key]
    }
    
    public func setExtraData(key: String, value: Any?)
    {
        if value == nil {
            extraDataDict.removeValueForKey(key)
        } else {
            extraDataDict[key] = value!
        }
    }
}

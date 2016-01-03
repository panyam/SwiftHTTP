
import SwiftIO

public class HttpRequest : HttpMessage, CustomStringConvertible {
    var method = "GET"
    var version = "HTTP 1.1"
    private var fullPath : String = ""
    var resourcePath : String = ""
    var fragment : String = ""
    var queryParams = StringMultiMap(caseSensitiveKeys: true)
    var reader : BufferedReader?
    
    public override func reset()
    {
        super.reset()
    }

    public var requestTarget : String {
        get {
            return fullPath
        }
        set (value) {
            fullPath = requestTarget
            if let urlComponents = NSURLComponents(string: value)
            {
                resourcePath = ""
                fragment = ""
                if urlComponents.path != nil
                {
                    resourcePath = urlComponents.path!
                }
                if urlComponents.fragment != nil
                {
                    fragment = urlComponents.fragment!
                }
                queryParams.removeAll()
                if let queryItems = urlComponents.queryItems
                {
                    queryItems.forEach({ (queryItem) -> () in
                        if queryItem.value != nil
                        {
                            queryParams.forKey(queryItem.name, create: true)?.addValue(queryItem.value!)
                        }
                    })
                }
            }
        }
    }

    public var description : String {
        return "\(method) \(requestTarget) \(version)\(CRLF)\(headers)"
    }
}

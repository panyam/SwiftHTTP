
import SwiftIO

let server = HttpServer(8888)

server.serve { (request, response) -> Void in
    // find the resource handler for this request
    // dispatch to it
    // it will be the resource hadnler's responsibility to:
    // 1. Set headers
    // 2. Set the body writer
    // 3. Close the response once it is done with it
    print("Handling request: \(request.method) \(request.requestTarget)")
    if request.resourcePath == "/"
    {
        response.headers.forKey("Content-Type", create: true)?.setValue(MimeType.typeForExtension("html"))
        response.setBodyWriter(FileBodyWriter("/Users/spanyam/personal/swiftli/tests/static/index.html"))
        response.close()
    }
    else if request.resourcePath.hasPrefix("/static/")
    {
        let path = request.resourcePath.substringFromIndex(request.resourcePath.startIndex.advancedBy(8))
        StaticFileHandler(root: "/Users/spanyam/personal/swiftli/tests/static/", path: path).serve(request, response)
    }
    else {
        response.setStatus(404, "Not Found")
        response.close()
    }
}

// This has to be started
CoreFoundationRunLoop.defaultRunLoop().start()


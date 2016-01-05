
import SwiftIO

func testHTTP1Server()
{
    let server = HttpServer(9001)
    
    server.serve { (request, response) in
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
            response.setBody(FileBody("/Users/spanyam/personal/SwiftHTTP/tests/static/index.html"))
            response.close()
        }
        else if request.resourcePath.hasPrefix("/static/")
        {
            let path = request.resourcePath.substringFromIndex(request.resourcePath.startIndex.advancedBy(8))
            StaticFileHandler(root: "/Users/spanyam/personal/SwiftHTTP/tests/static/", path: path).serve(request, response)
        }
        else {
            response.setStatus(HttpStatusCode.NotFound)
            response.close()
        }
    }
    
    // This has to be started
    CoreFoundationRunLoop.defaultRunLoop().start()
}

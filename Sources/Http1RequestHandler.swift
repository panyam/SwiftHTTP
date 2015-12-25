//
//  Http1StreamHandler.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/16/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public class Http1RequestHandler : HttpRequestHandler
{
    public func handleRequest(request: HttpRequest, response: HttpResponse)
    {
        // find the resource handler for this request
        // dispatch to it
        // it will be the resource hadnler's responsibility to:
        // 1. Set headers
        // 2. Set the body writer
        // 3. Close the response once it is done with it
        print("Handling request: \(request.method) \(request.requestTarget)")
        if request.requestTarget == "/favicon.ico" {
            // 404
            response.setStatus(404, "Not Found")
        } else {
            response.headers.forKey("Content-Type", create: true)?.setValue(MimeType.typeForExtension(".html"))
            response.setBodyWriter(FileBodyWriter("/Users/spanyam/personal/swiftli/tests/static/index.html"))
        }
        response.close()
    }
}
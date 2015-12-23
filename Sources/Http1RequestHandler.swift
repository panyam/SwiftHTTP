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
        print("Handling request...")
        // the following need to happen to handle a 1.0/1.1 typed request:
        // 1. Set response code and message
        // 2. Set any headers we need
        // 3. write body
        //
        // First 2 are straight forward. 3rd is the tricky one.  We have the following scenarios:
        // 1. We know the body length and it is small so 

//        let statusCode = 200
//        response.setStatus(statusCode, nil)
//
//        // set transfer encoder so it can handle how data is sent out
//        // There can only be transfer encoding *or* content-length
//        response.transferEncoder = encoder chain followed by chunked (always appears exactly once and at the end)
//        while data_available {
//            data = getdata()
//            response.writer.write(data)
//        }
//        // to indicate response has finished
//        response.close()
    }
}
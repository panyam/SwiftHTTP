//
//  StaticFileHandler.swift
//  SwiftHTTP
//
//  Created by Sriram Panyam on 12/25/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public class StaticFileHandler
{
    var root : String
    var path : String
    public init(root: String, path: String)
    {
        self.root = root
        self.path = path
    }
    
    public func serve(request: HttpRequest, _ response: HttpResponse)
    {
        let fullPath = root + path
        let fileURL = NSURL(fileURLWithPath: fullPath)
        if let pathExt = fileURL.pathExtension
        {
            response.headers.forKey("Content-Type", create: true)?.setValue(MimeType.typeForExtension(pathExt))
        } else {
            response.headers.forKey("Content-Type", create: true)?.setValue(MimeType.typeForExtension("application/octet-stream"))
        }
        response.setBody(FileBody(fullPath))
        response.close()
    }
}

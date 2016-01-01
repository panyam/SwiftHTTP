//
//  HttpBody.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/24/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import SwiftIO

/**
 * Responsible for generating payload for a http response.
 * This can be used any time payload is expected for a response or a frame
 * within a response.
 */
public protocol HttpBody : Payload {
    /**
     * Give the body generator a chance to decorate the response by changing
     * response codes, headers etc
     */
    func decorateResponse(response: HttpResponse)
}

public class FileBody : FilePayload, HttpBody
{
    public func decorateResponse(response: HttpResponse) {
        // TODO: Check file stats and readability and other file attributes
        do {
            fileAttrs = try NSFileManager.defaultManager().attributesOfItemAtPath(filePath)
            
            if fileAttrs == nil {
                response.setStatus(HttpStatusCode.NotFound)
            } else {
                if (fileAttrs![NSFileType] as! String) != NSFileTypeRegular {
                    // unable to get it so send a Not found
                    response.setStatus(HttpStatusCode.BadRequest)
                }
            }
        } catch {
            // unable to get it so send a Not found
            response.setStatus(HttpStatusCode.BadRequest)
        }
    }
}

//
//  HttpConnectionDelegate.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/16/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public protocol HttpConnectionDelegate {
    func didStartNewRequest(connection: HttpConnection, method: String, requestTarget: String, version: String)
    func didReceiveHeader(connection: HttpConnection, key: String, value: String)
    func didReceiveHeaders(connection: HttpConnection)
    func createRequestHandler(connection: HttpConnection, request: HttpRequest) -> HttpRequestHandler?
}
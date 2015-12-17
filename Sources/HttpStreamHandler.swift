//
//  HttpStreamHandler.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/16/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public protocol HttpStreamHandler {
    func processData(buffer: UnsafePointer<UInt8>, _ offset: Int, _ length: Int) -> Int
}
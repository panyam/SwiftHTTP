//
//  observable.swift
//  SwiftHTTPDemos
//
//  Created by Sriram Panyam on 2/11/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import RxSwift
import SwiftIO
import SwiftHTTP

// testing out observable streams
// This is a sample echo server
// Unlike a normal echo server, it simply prints messages sent to it 
// on the screen.  AND every 100 bytes it pauses for a second


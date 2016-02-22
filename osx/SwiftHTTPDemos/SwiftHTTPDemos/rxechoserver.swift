//
//  rxechoserver.swift
//  SwiftHTTPDemos
//
//  Created by Sriram Panyam on 2/19/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import SwiftIO
import SwiftHTTP
import RxSwift

func testRxEchoServer()
{
    let server = RxServer(9001)
    server.serve { (receiver: DataReceiver) -> DataSource in
        // need to return an object takes the receiver and returns a source that echoes it out!
    }
}

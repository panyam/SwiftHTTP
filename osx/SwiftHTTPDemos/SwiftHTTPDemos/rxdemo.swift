//
//  rxdemo.swift
//  SwiftHTTPDemos
//
//  Created by Sriram Panyam on 2/17/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import SwiftIO
import SwiftHTTP
import RxSwift

func testRxHTTP1Server()
{
//    var connectionCount = 0
//    let server = RxServer(9001)
/**
we need something like:

server.serve()
    .flatMap(some that function that takes stream and RETURNS Observable<DataReceivedEvents>.  This event will allow reading of bytes as well as "pausing" of future events - kind of backpressure)
    .flatMap(dataReceivedEvent -> builds some part of the request and returns an Observable<HttpConnection>)    httpConnection has currentReq and currentRes vars
    .flatMap(httpConnection -> 
        // response written - 
    let _ = server.serve().flatMap({ (stream: Stream) -> Observable<HttpRequest> in
        connectionCount += 1
        let httpconn = HttpConnection(reader: stream.consumer as! Reader, writer: stream.producer as! Writer)
        httpconn.identifier = String(format: "%03d", connectionCount)
//        httpconn.requestHandler = requestHandler
//        httpconn.delegate = self
        return httpconn.serve()
    }).flat
//    server.streamObservable.fl
}

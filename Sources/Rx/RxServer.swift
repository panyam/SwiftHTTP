//
//  ObserverableServer.swift
//  SwiftHTTP
//
//  Created by Sriram Panyam on 2/17/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import SwiftIO
import RxSwift

public class RxServer : StreamHandler
{
    var socketServer = CFSocketServer(nil)
    var streams = [Stream]()
    var serverPort: UInt16 = 8888
    var streamHandlerFunc : (Stream -> Void) = { _ in }
    private(set) lazy var streamObservable : Observable<Stream> = {
        self.createObservable()
    }()
    
    public init(_ port: UInt16)
    {
        serverPort = port
    }
    
    public func handleStream(let stream: Stream) {
        streamHandlerFunc(stream)
    }
    
    public func serve() -> Observable<Stream>
    {
        socketServer.serverPort = serverPort
        socketServer.streamHandler = self
        socketServer.start()
        return streamObservable
    }
    
    private func createObservable() -> Observable<Stream>
    {
        return Observable.create { (observer: AnyObserver<Stream>) -> Disposable in
            self.streamHandlerFunc = {(var stream: Stream) in
                stream.consumer = StreamReader(stream)
                stream.producer = StreamWriter(stream)
                observer.onNext(stream)
            }
            return AnonymousDisposable({})
        }
    }
}

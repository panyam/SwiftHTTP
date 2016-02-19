//
//  ObserverableServer.swift
//  SwiftHTTP
//
//  Created by Sriram Panyam on 2/17/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import SwiftIO
import RxSwift

public protocol Pausable {
    func pause()
    func resume()
}

public class ReadEvent {
    // The source of the events which can be paused and/or resumed to
    // apply backpressure
    public var source : Pausable
    // The receiver from which data can be read for as long as we want
    public var receiver : DataReceiver
    
    public init(source : Pausable, receiver : DataReceiver) {
        self.source = source
        self.receiver = receiver
    }
}

public class WriteEvent {
    // The source of the events which can be paused and/or resumed to
    // apply backpressure
    public var source : Pausable
    // The receiver from which data can be read for as long as we want
    public var sender : DataSender
    
    public init(source : Pausable, sender : DataSender) {
        self.source = source
        self.sender = sender
    }
}

public class RxServer : StreamHandler
{
    class RxConnection {
        var stream : Stream?
        var observable : Observable<WriteEvent>?
    }
    
    public typealias ReadEventHandler = (event : ReadEvent) -> Observable<WriteEvent>
    var socketServer = CFSocketServer(nil)
    var connections = [RxConnection]()
    var serverPort: UInt16 = 8888
    var readEventHandler : ReadEventHandler?
    
    public init(_ port: UInt16)
    {
        serverPort = port
    }
    
    public func handleStream(let stream: Stream) {
        // here we need to create an observable of DataReadable events from the StreamReader
        // and pipe it to some session handler which would create a stream
        // of DataWritable events and pipe those to the SteramReader
        let connection = RxConnection()
        connection.stream = stream
        connection.observable = createReadEventObservable(stream)
                                    .flatMap(readEventHandler!)
        connections.append(connection)
    }
    
    private func createReadEventObservable(var stream : Stream) -> Observable<ReadEvent> {
        // TODO: Actually have to fill in the magic that this is blank
        stream.consumer = StreamReader(stream)
        stream.producer = StreamWriter(stream)
//        return Observable.create { (observer: AnyObserver<Stream>) -> Disposable in
//            self.streamHandlerFunc = {(var stream: Stream) in
//                observer.onNext(stream)
//            }
//            return AnonymousDisposable({})
//        }
        return Observable.create({ (observer: AnyObserver<ReadEvent>) -> Disposable in
            return AnonymousDisposable({})
        })
    }
    
    public func serve(handler : ReadEventHandler)
    {
        readEventHandler = handler
        socketServer.serverPort = serverPort
        socketServer.streamHandler = self
        socketServer.start()
    }
}

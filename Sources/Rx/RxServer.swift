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

public protocol DataSource {
    func sendWith(sender: DataSender) -> (Bool, ErrorType?)
}
//
//public class DataSource : DataSource {
//    // The receiver from which data can be read for as long as we want
//    public var receiver : DataReceiver
//    
//    public init(receiver : DataReceiver) {
//        self.receiver = receiver
//        self.source = source
//    }
//    
//    public func sendWith(sender: DataSender) -> (Bool, ErrorType?) {
//        return (true, nil)
//    }
//}

public class RxServer : StreamHandler
{
    public typealias DataSourceCreator = (DataReceiver) -> DataSource
    var socketServer = CFSocketServer(nil)
    var connections = [RxConnection]()
    var serverPort: UInt16 = 8888

    var dataSourceCreator : DataSourceCreator?

    public init(_ port: UInt16)
    {
        serverPort = port
    }
    
    public func handleStream(var stream: Stream) {
        // here we need to create an observable of DataReadable events from the StreamReader
        // and pipe it to some session handler which would create a stream
        // of DataWritable events and pipe those to the SteramReader
        let connection = RxConnection(stream)
        connection.stream = stream
        stream.producer = createDataSourceProducer(connection)
        connection.observable = createDataSourceConsumer(stream)
            .map({ (source: DataSource) in
                connection.addSource(source)
            })
        connections.append(connection)
    }
    
    private func createDataSourceConsumer(var stream : Stream) -> Observable<DataSource> {
        let callbackConsumer = CallbackStreamConsumer(stream)
        stream.consumer = callbackConsumer

        return Observable.create { (observer: AnyObserver<DataSource>) -> Disposable in
            callbackConsumer.onClosed = { observer.onCompleted() }
            callbackConsumer.onError = { observer.onError($0) }
            callbackConsumer.onDataReceivable = { (receiver : DataReceiver) -> Bool in
                observer.onNext(self.dataSourceCreator!(receiver))
                return true
            }
            return AnonymousDisposable({})
        }
    }

    private func createDataSourceProducer( connection : RxConnection) -> StreamProducer {
        let callbackProducer = CallbackStreamProducer(connection.stream)
        callbackProducer.onDataSendable = {(sender : DataSender) in
            // the sender can be sent invoked to send *something*, 
            // something has to be given this so it can push stuff through the sender.
            // It just so happens that the connection has a list of sources waiting
            // to send data, 
            // The write event needs to indicate that some "source" is ready to
            // send data via the DataSender.  The contract is that the DataSource
            // must only cally the DataSender.write as long as it can (or an error or EOF is returned).
            // After this point, it must return the number of bytes returned along with
            // true/false if there is more data to be written.
            return connection.flushWith(sender)
        }
        return callbackProducer
    }
    
    public func serve(handler : DataSourceCreator)
    {
        dataSourceCreator = handler
        socketServer.serverPort = serverPort
        socketServer.streamHandler = self
        socketServer.start()
    }
}

public class RxConnection {
    public var stream : Stream
    public var observable : Observable<Void>?
    
    // List of data sources that are pending
    var pendingDataSources = [DataSource]()
    
    /**
     * Any connection specific context that needs to be maintained.
     */
    public var context : AnyObject?
    
    public init(_ stream: Stream) {
        self.stream = stream
    }
    
    func addSource(source : DataSource) {
        pendingDataSources.append(source)
        stream.setReadyToWrite()
    }
    
    func flushWith(sender: DataSender) -> Bool {
        // make stream not ready to read as we have a fair bit of data to write
        // TODO: may be only do this if a certain threshold has reached?
        stream.clearReadyToRead()
        while let source = pendingDataSources.first {
            let (finished, error) = source.sendWith(sender)
            if error != nil {
                // TODO: how to handle error
                return true
            }
            else if finished {
                pendingDataSources.removeFirst()
            } else {
                // not able to send any more so no point in trying again
                stream.setReadyToWrite()
                return true
            }
        }
        return false
    }
}

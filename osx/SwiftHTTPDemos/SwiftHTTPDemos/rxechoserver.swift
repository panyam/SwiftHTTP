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
    server.serve { (receiver: DataReceiver) -> Observable<DataSource> in
        let buffer = ReadBufferType.alloc(DEFAULT_BUFFER_LENGTH)
        var lastReadLength = 0
        var lastReadOffset = 0
        var writeLength = 0
        var error : ErrorType?
        let dataSource = AnonymousDataSource {(sender : DataSender) -> (Bool, ErrorType?) in
            // if some data is left then write that first
            while true {
                if lastReadOffset < lastReadLength {
                    (writeLength, error) = sender.write(buffer.advancedBy(lastReadOffset), length: lastReadLength - lastReadOffset)
                } else {
                    lastReadOffset = 0
                    lastReadLength = 0
                    (lastReadLength, error) = receiver.read(buffer, length: DEFAULT_BUFFER_LENGTH)
                    if error != nil {
                        return (false, error)       // read error
                    } else if lastReadLength == 0 {
                        // no more data left in this receiver
                        return (false, nil)
                    } else {
                        // write data to sender as it is now writable
                        (writeLength, error) = sender.write(buffer.advancedBy(lastReadOffset), length: lastReadLength - lastReadOffset)
                    }
                }
                if error != nil {
                    return (false, error)   // write error
                } else if writeLength == 0 {
                    return (false, nil)     // cannot write any more data
                } else {
                    lastReadOffset += writeLength
                    // write successful, so see if need to read more data
                    return (true, nil)
                }
            }
        }
        return Observable.of(dataSource)
    }
}

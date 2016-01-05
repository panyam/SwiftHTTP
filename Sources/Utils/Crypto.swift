//
//  Crypto.swift
//  SwiftHTTP
//
//  Created by Sriram Panyam on 12/27/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

extension String {
    func SHA1Bytes() -> NSData
    {
        let data = self.dataUsingEncoding(NSUTF8StringEncoding)!
        var digest = [UInt8](count:Int(CC_SHA1_DIGEST_LENGTH), repeatedValue: 0)
        CC_SHA1(data.bytes, CC_LONG(data.length), &digest)
        return NSData(bytes: digest, length: Int(CC_SHA1_DIGEST_LENGTH))
    }

    func SHA1() -> String
    {
        let data = self.dataUsingEncoding(NSUTF8StringEncoding)!
        var digest = [UInt8](count:Int(CC_SHA1_DIGEST_LENGTH), repeatedValue: 0)
        CC_SHA1(data.bytes, CC_LONG(data.length), &digest)
        let hexBytes = digest.map { String(format: "%02hhx", $0) }
        return hexBytes.joinWithSeparator("")
    }
}

//
//  Base64.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/27/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public class BaseXEncoding
{
    public static let Base64Alphabet    = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    public static let Base64UrlAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
    public static let Base32Alphabet    = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
    public static let Base32HexAlphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUV"
    public static let Base16Alphabet    = "0123456789ABCDEF"
    
    public static func Base64DecodeData(string: String?) -> NSData?
    {
        if string != nil
        {
            return NSData(base64EncodedString: string!, options: NSDataBase64DecodingOptions(rawValue: 0))
        }
        return nil
    }
    
    public static func Base64Decode(string: String?) -> String?
    {
        if let decodedData = Base64DecodeData(string)
        {
            return NSString(data: decodedData, encoding: NSASCIIStringEncoding) as String?
        }
        return nil
    }
    
    public static func Base64Encode(string: String?) -> String?
    {
        if string != nil
        {
            let plainData = (string! as NSString).dataUsingEncoding(NSUTF8StringEncoding)
            return plainData?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
        }
        return nil
    }
    
    public static func Base64Encode(data: NSData?) -> String?
    {
        return data?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
    }

//
//    public static func Base64Encode(buffer: UnsafePointer<UInt8>, length: LengthType, output: UnsafeMutablePointer<UInt8>) -> UInt
//    {
//        var nDone = 0
//        var mask = (1 << 6) - 1
//        var remaining
//        for i in 0..<length
//        {
//            
//        }
//        return nDone
//    }
}

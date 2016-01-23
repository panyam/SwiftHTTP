//
//  Strings.swift
//  SwiftHTTP
//
//  Created by Sriram Panyam on 1/23/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import Foundation

public extension String
{
    static var DQUOTE = Character(UnicodeScalar(34))
    static var SQUOTE = Character(UnicodeScalar(39))
    
    /**
     * Tells if the string is double quoted
     */
    public func isDoubleQuoted() -> Bool {
        return characters.first == String.DQUOTE && characters.last == String.DQUOTE
    }
    
    /**
     * Tells if the string is single quoted
     */
    public func isSingleQuoted() -> Bool {
        return characters.first == String.SQUOTE && characters.last == String.SQUOTE
    }
    
    /**
     * Tells if the string is single or double quoted
     */
    public func isQuoted() -> Bool {
        return isSingleQuoted() || isDoubleQuoted()
    }
    
    public func quotesStripped() -> String {
        if isQuoted()
        {
            return substringWithRange(Range(start: startIndex.successor(), end: endIndex.predecessor()))
        }
        return self
    }
}
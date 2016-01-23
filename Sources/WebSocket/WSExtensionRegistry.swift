//
//  WSExtensionRegistry.swift
//  SwiftHTTP
//
//  Created by Sriram Panyam on 1/23/16.
//  Copyright © 2016 Sriram Panyam. All rights reserved.
//

import SwiftIO

public protocol WSExtensionFactory
{
    func createExtension(name: String, arguments: [(String, String)]) -> WSExtension?
}

public class WSExtensionRegistry
{
    private var factoriesMap = [String: [WSExtensionFactory]]()

    public func registerFactory(name: String, factory: WSExtensionFactory)
    {
        if factoriesMap[name] == nil
        {
            factoriesMap[name] = [WSExtensionFactory]()
        }
        factoriesMap[name]!.append(factory)
    }
    
    public func createExtension(name: String, arguments: [(String, String)]) -> WSExtension?
    {
        if let factories = factoriesMap[name]
        {
            for factory in factories {
                if let ext = factory.createExtension(name, arguments: arguments)
                {
                    return ext
                }
            }
        }
        return nil
    }
}

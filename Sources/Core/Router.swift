//
//  Router.swift
//  swiftli
//
//  Created by Sriram Panyam on 12/25/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public typealias HeaderNameValuePair = (name: String, value: String)

//public class MatchResult
//{
//    var route : Route?
//    var variables : [String : AnyObject] = [String : AnyObject]()
//    var handler : HttpRequestHandler?
//}
//
///**
// * Matcher objects
// */
//public protocol Matcher
//{
//    func match(request: HttpRequest, _ result: MatchResult) -> Bool
//}
//
//public class HostMatcher
//{
//}
//
//public class QueryParamMatcher
//{
//    /**
//     * Matched based on query parameters
//     */
//    func match(request: HttpRequest, _ result: MatchResult) -> Bool
//    {
//    }
//}
//
///**
// * Returns a http handler method for a given request.
// */
//public class Router : RouteMatcher
//{
//    var routes : [Route] = [Route]()
//
//    public init()
//    {
//    }
//    
//    public func match(request: HttpRequest, _ result: MatchResult) -> Bool {
//        for route in routes {
//            if route.match(request, result) {
//                return true
//            }
//        }
//        return false
//    }
//
//    public func handler() -> HttpRequestHandler
//    {
//        return {(request, response) -> Void in
//        }
//    }
//}
//public class Route : RouteMatcher
//{
//    /**
//     * Optional name of the route
//     */
//    var name : String = ""
//    
//    /**
//     */
//    private (set) var parentRoute : Route?
//    var matchers : [RouteMatcher] = [RouteMatcher]()
//
//    public convenience init()
//    {
//        self.init("", nil)
//    }
//
//    public init(_ name: String, _ parent : Route?)
//    {
//        name = n
//        parentRoute = parent
//    }
//
//    func match(request: HttpRequest, result: MatchResult) -> Bool
//    {
//        for matcher in matchers {
//            if matcher.match(reqeust, result: result)
//        }
//    }
//    
//    public func Methods(methods: String...) -> Route {
//        matchers.append {(request: HttpRequest) -> Bool in
//            for method in methods {
//                if methods.contains(method) {
//                    return true
//                }
//            }
//            return false
//        }
//        return Route(self)
//    }
//    
//    public func Header(values: HeaderNameValuePair...) -> Route {
//        matchers.append {(request: HttpRequest) -> Bool in
//            for (name, value) in values {
//                if let headerValue = request.headers.forKey(name)?.values.first
//                {
//                    if headerValue != value
//                    {
//                        return false
//                    }
//                } else {
//                    return false
//                }
//            }
//            return true
//        }
//        return Route(self)
//    }
//}

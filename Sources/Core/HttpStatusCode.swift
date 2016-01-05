//
//  HttpStatusCode.swift
//  SwiftHTTP
//
//  Created by Sriram Panyam on 12/27/15.
//  Copyright © 2015 Sriram Panyam. All rights reserved.
//

import Foundation

public enum HttpStatusCode : Int
{
    case Continue = 100
    case SwitchingProtocols = 101
    
    case Ok = 200
    case Created = 201
    case Accepted = 202
    case NonAuthoritativeInformation = 203
    case NoContent = 204
    case ResetContent = 205
    case PartialContent = 206
    
    case MultipleChoices = 300
    case MovedPermanently = 301
    case Found = 302
    case SeeOther = 303
    case NotModified = 304
    case UseProxy = 305
    case TemporaryRedirect = 307
    
    case BadRequest = 400
    case Unauthorized = 401
    case PaymentRequired = 402
    case Forbidden = 403
    case NotFound = 404
    case MethodNotAllowed = 405
    case NotAcceptable = 406
    case ProxyAuthenticationRequired = 407
    case RequestTimeout = 408
    case Conflict = 409
    case Gone = 410
    case LengthRequired = 411
    case PerconditionFailed = 412
    case RequestEntityTooLarge = 413
    case RequestURITooLong = 414
    case UnsupportedMediaType = 415
    case RequestRangeNotSatisfiable = 416
    case ExpectationFailed = 417
    
    case InternalServerError = 500
    case NotImplemented = 501
    case BadGateway = 502
    case ServiceUnavailable = 503
    case GatewayTimeout = 504
    case HTTPVersionNotSupported = 505
}


extension HttpStatusCode
{
    static let reasonPhrases : [Int : String] = [
        Continue.rawValue: "Continue",
        SwitchingProtocols.rawValue: "SwitchingProtocols",

        Ok.rawValue: "Ok",
        Created.rawValue: "Created",
        Accepted.rawValue: "Accepted",
        NonAuthoritativeInformation.rawValue: "NonAuthoritativeInformation",
        NoContent.rawValue: "NoContent",
        ResetContent.rawValue: "ResetContent",
        PartialContent.rawValue: "PartialContent",

        MultipleChoices.rawValue: "MultipleChoices",
        MovedPermanently.rawValue: "MovedPermanently",
        Found.rawValue: "Found",
        SeeOther.rawValue: "SeeOther",
        NotModified.rawValue: "NotModified",
        UseProxy.rawValue: "UseProxy",
        TemporaryRedirect.rawValue: "TemporaryRedirect",

        BadRequest.rawValue: "BadRequest",
        Unauthorized.rawValue: "Unauthorized",
        PaymentRequired.rawValue: "PaymentRequired",
        Forbidden.rawValue: "Forbidden",
        NotFound.rawValue: "NotFound",
        MethodNotAllowed.rawValue: "MethodNotAllowed",
        NotAcceptable.rawValue: "NotAcceptable",
        ProxyAuthenticationRequired.rawValue: "ProxyAuthenticationRequired",
        RequestTimeout.rawValue: "RequestTimeout",
        Conflict.rawValue: "Conflict",
        Gone.rawValue: "Gone",
        LengthRequired.rawValue: "LengthRequired",
        PerconditionFailed.rawValue: "PerconditionFailed",
        RequestEntityTooLarge.rawValue: "RequestEntityTooLarge",
        RequestURITooLong.rawValue: "RequestURITooLong",
        UnsupportedMediaType.rawValue: "UnsupportedMediaType",
        RequestRangeNotSatisfiable.rawValue: "RequestRangeNotSatisfiable",
        ExpectationFailed.rawValue: "ExpectationFailed",

        InternalServerError.rawValue: "InternalServerError",
        NotImplemented.rawValue: "NotImplemented",
        BadGateway.rawValue: "BadGateway",
        ServiceUnavailable.rawValue: "ServiceUnavailable",
        GatewayTimeout.rawValue: "GatewayTimeout",
        HTTPVersionNotSupported.rawValue: "HTTPVersionNotSupported"
    ]
    
    public func reasonPhrase() -> String?
    {
        return HttpStatusCode.reasonPhrases[self.rawValue]
    }
}

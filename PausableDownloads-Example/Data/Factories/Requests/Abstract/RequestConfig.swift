//
//  RequestConfig.swift
//  DownloadStack-Example
//
//  Created by William Boles on 07/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

enum HTTPRequestMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

class RequestConfig {
    
    let clientID: String
    let APIHost: String
    let timeInterval: TimeInterval
    let cachePolicy: NSURLRequest.CachePolicy
    
    // MARK: - Shared
    
    static let shared = RequestConfig()
    
    // MARK: - Init
    
    init() {
        self.clientID = "Replace" //TODO: Added youe clientID here
        self.APIHost = "https://api.imgur.com/3"
        self.timeInterval = 45
        self.cachePolicy = .useProtocolCachePolicy
        
        assert(!clientID.isEmpty, "You need to provide a clientID hash, you get this from: https://api.imgur.com/oauth2/addclient")
    }
}

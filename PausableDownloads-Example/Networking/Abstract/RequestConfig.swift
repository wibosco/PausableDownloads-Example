//
//  RequestConfig.swift
//  DownloadStack-Example
//
//  Created by William Boles on 07/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation
import os

enum HTTPRequestMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

class RequestConfig {
    let apiKey: String
    let APIHost: String
    let timeInterval: TimeInterval
    let cachePolicy: NSURLRequest.CachePolicy
    
    // MARK: - Shared
    
    static let shared = RequestConfig()
    
    // MARK: - Init
    
    init() {
        self.apiKey = Bundle.main.object(forInfoDictionaryKey: "CatAPIKey") as? String ?? "" // Add your API key from: https://thecatapi.com/
        self.APIHost = "https://api.thecatapi.com/v1"
        self.timeInterval = 45
        self.cachePolicy = .useProtocolCachePolicy
        
        if apiKey.isEmpty {
            os_log(.error, """
            *******************************************************************************  
            *******************************************************************************  
            *******************************************************************************  
            ******************************* MISSING API KEY *******************************
            *******************************************************************************  
            ******************************************************************************* 
            ******************************************************************************* 
            """)
        }
    }
}

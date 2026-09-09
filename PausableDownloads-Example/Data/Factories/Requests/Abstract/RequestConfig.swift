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
    
    let clientID: String
    let APIHost: String
    let timeInterval: TimeInterval
    let cachePolicy: NSURLRequest.CachePolicy
    
    // MARK: - Shared
    
    static let shared = RequestConfig()
    
    // MARK: - Init
    
    init() {
        self.clientID = Bundle.main.object(forInfoDictionaryKey: "ClientID") as? String ?? "" // Add your API key from: https://api.imgur.com/oauth2/addclient //"REPLACE_ME" //TODO: Added your clientID here
        self.APIHost = "https://api.imgur.com/3"
        self.timeInterval = 45
        self.cachePolicy = .useProtocolCachePolicy
        
        if clientID.isEmpty {
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

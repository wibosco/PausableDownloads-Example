//
//  CatImagesURLRequestFactory.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 07/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

class ImagesURLRequestFactory: URLRequestFactory {
    
    // MARK: - Retrieval
    
    func requestToRetrieveImages(limit: Int = 10) -> URLRequest {
        var request = jsonRequest(endPoint: "images/search?limit=\(limit)&order=RANDOM&size=full")
        request.httpMethod = HTTPRequestMethod.get.rawValue
        
        return request
    }
}

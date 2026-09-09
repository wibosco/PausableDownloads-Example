//
//  CatImagesURLRequestFactory.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 07/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

class CatImagesURLRequestFactory: URLRequestFactory {
    
    // MARK: - Retrieval
    
    //`order=RANDOM` as TheCatAPI has no chronological ordering - `ASC`/`DESC` sort by id,
    //which always surfaces the same legacy images
    func requestToRetrieveImages(limit: Int = 30) -> URLRequest {
        var request = jsonRequest(endPoint: "images/search?limit=\(limit)&order=RANDOM")
        request.httpMethod = HTTPRequestMethod.get.rawValue
        
        return request
    }
}

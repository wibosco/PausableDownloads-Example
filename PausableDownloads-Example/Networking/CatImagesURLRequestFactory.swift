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
    //which always surfaces the same legacy images.
    //`size=full` returns the originals rather than resized copies - small assets finish
    //downloading before there's any chance to pause one, which is the whole point here
    func requestToRetrieveImages(limit: Int = 10) -> URLRequest {
        var request = jsonRequest(endPoint: "images/search?limit=\(limit)&order=RANDOM&size=full")
        request.httpMethod = HTTPRequestMethod.get.rawValue
        
        return request
    }
}

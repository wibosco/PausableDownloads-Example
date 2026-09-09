//
//  CatImage.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 17/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

struct CatImage: Decodable, Equatable {
    
    let identifier: String
    let url: URL
    let width: Int
    let height: Int
    
    private enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case url
        case width
        case height
    }
    
    // MARK: - Cache
    
    func cachedLocalAssetURL() -> URL {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last!
        let fileName = "\(identifier).\(url.pathExtension)"
        
        return cacheURL.appendingPathComponent(fileName)
    }
}

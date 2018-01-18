//
//  Asset.swift
//  SmartMediaDownloader-Example
//
//  Created by William Boles on 17/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

struct Asset {
    
    let id: String
    let url: URL
    
    // MARK: - Location
    
    func cachedLocalAssetURL() -> URL {
        let cacheURL = FileManager.default.urls(for: FileManager.SearchPathDirectory.cachesDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).last!
        let fileName = url.deletingPathExtension().lastPathComponent
        return cacheURL.appendingPathComponent(fileName)
    }
    
}

extension Asset: Equatable {}

func ==(lhs: Asset, rhs: Asset) -> Bool {
    return lhs.id == rhs.id &&
        lhs.url == rhs.url
}

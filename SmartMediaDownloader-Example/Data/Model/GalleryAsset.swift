//
//  GalleryAsset.swift
//  SmartMediaDownloader-Example
//
//  Created by William Boles on 17/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

struct GalleryAsset {
    
    let id: String
    let url: URL
    
    // MARK: - Location
    
    func cachedLocalAssetURL() -> URL {
        let cacheURL = FileManager.default.urls(for: FileManager.SearchPathDirectory.cachesDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).last!
        let fileName = url.deletingPathExtension().lastPathComponent
        return cacheURL.appendingPathComponent(fileName)
    }
    
}

extension GalleryAsset: Equatable {}

func ==(lhs: GalleryAsset, rhs: GalleryAsset) -> Bool {
    return lhs.id == rhs.id &&
        lhs.url == rhs.url
}

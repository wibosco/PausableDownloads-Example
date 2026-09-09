//
//  ImageDomainModel.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation

struct ImageDomainModel: Equatable {
    let identifier: String
    let url: URL
    let width: Int
    let height: Int
    
    // MARK: - Cache
    
    func cachedLocalAssetURL() -> URL {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last!
        let fileName = "\(identifier).\(url.pathExtension)"
        
        return cacheURL.appendingPathComponent(fileName)
    }
}

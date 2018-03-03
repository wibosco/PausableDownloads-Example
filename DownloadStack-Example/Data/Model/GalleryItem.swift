//
//  GalleryImageAsset.swift
//  DownloadStack-Example
//
//  Created by William Boles on 07/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

struct GalleryItem {
    
    let title: String
    let asset: GalleryAsset
}

extension GalleryItem: Equatable {
    static func ==(lhs: GalleryItem, rhs: GalleryItem) -> Bool {
        return lhs.title == rhs.title &&
            lhs.asset == rhs.asset
    }
}

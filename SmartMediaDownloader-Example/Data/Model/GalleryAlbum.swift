//
//  GalleryAlbum.swift
//  SmartMediaDownloader-Example
//
//  Created by William Boles on 17/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

struct GalleryAlbum {
    
    let thumbnailAsset: GalleryAsset
    let items: [GalleryItem]
}

extension GalleryAlbum: Equatable {}

func ==(lhs: GalleryAlbum, rhs: GalleryAlbum) -> Bool {
    return lhs.thumbnailAsset == rhs.thumbnailAsset &&
        lhs.items == rhs.items
}

//
//  GalleryAlbum.swift
//  UnequalDownloads-Example
//
//  Created by William Boles on 17/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

struct GalleryAlbum: Equatable {
    
    let thumbnailAsset: GalleryAsset
    let items: [GalleryItem]
}

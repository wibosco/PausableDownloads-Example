//
//  ImagesDomainModelFactory.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation

struct ImagesDomainModelFactory {
    
    // MARK: - Build
    
    func buildImage(from dto: ImageDTO) -> ImageDomainModel {
        return ImageDomainModel(identifier: dto.id,
                                url: dto.url,
                                width: dto.width,
                                height: dto.height)
    }
}

//
//  StubAssetService.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation

@testable import PausableDownloads_Example

final class StubAssetService: AssetService {
    enum Event {
        case loadImage(ImageDomainModel, DispatchQueue, (Result<PausableDownloads_Example.LoadImageResult, any Error>) -> ())
        case cancelLoadingImage(ImageDomainModel)
    }
    
    private(set) var events = [Event]()
    
    func loadImage(_ imageDomainModel: ImageDomainModel,
                   callbackQueue: DispatchQueue,
                   completionHandler: @escaping (Result<PausableDownloads_Example.LoadImageResult, any Error>) -> ()) {
        events.append(.loadImage(imageDomainModel, callbackQueue, completionHandler))
    }
    
    func cancelLoadingImage(_ imageDomainModel: ImageDomainModel) {
        events.append(.cancelLoadingImage(imageDomainModel))
    }
}

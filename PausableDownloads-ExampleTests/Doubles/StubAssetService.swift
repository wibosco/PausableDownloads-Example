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
        case loadImage(ImageDomainModel, DispatchQueue, ((_ result: Result<LoadImageResult, Error>) -> ()))
        case cancelLoadingImage(DownloadToken)
    }
    
    private(set) var events = [Event]()
    
    var downloadTokenToReturn: DownloadToken?
    
    @discardableResult
    func loadImage(_ imageDomainModel: ImageDomainModel,
                   callbackQueue: DispatchQueue,
                   completionHandler: @escaping ((_ result: Result<LoadImageResult, Error>) -> ())) -> DownloadToken? {
        events.append(.loadImage(imageDomainModel, callbackQueue, completionHandler))
        
        return downloadTokenToReturn
    }
    
    func cancelLoadingImage(_ downloadToken: DownloadToken) {
        events.append(.cancelLoadingImage(downloadToken))
    }
}

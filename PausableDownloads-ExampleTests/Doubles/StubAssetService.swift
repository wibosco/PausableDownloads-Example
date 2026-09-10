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
        case cancelLoadingImage(DownloadToken)
    }
    
    private(set) var events = [Event]()
    
    //a fresh id per load, in issue order, so a test can say which download was cancelled
    private(set) var issuedDownloadIDs = [DownloadToken]()
    
    @discardableResult
    func loadImage(_ imageDomainModel: ImageDomainModel,
                   callbackQueue: DispatchQueue,
                   completionHandler: @escaping (Result<PausableDownloads_Example.LoadImageResult, any Error>) -> ()) -> DownloadToken? {
        events.append(.loadImage(imageDomainModel, callbackQueue, completionHandler))
        
        let downloadID = DownloadToken(url: imageDomainModel.url)
        issuedDownloadIDs.append(downloadID)
        
        return downloadID
    }
    
    func cancelLoadingImage(_ downloadID: DownloadToken) {
        events.append(.cancelLoadingImage(downloadID))
    }
}

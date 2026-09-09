//
//  AssetService.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 15/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation
import UIKit

struct LoadImageResult: Equatable {
    let imageDomainModel: ImageDomainModel
    let image: UIImage
}

class AssetService {
    private let assetDownloadSession = AssetDownloadsSession.shared
    private let fileManager = FileManager.default
    
    // MARK: - imageDomainModel
    
    func loadImage(_ imageDomainModel: ImageDomainModel,
                   completionHandler: @escaping ((_ result: Result<LoadImageResult, Error>) -> ())) {
        if fileManager.fileExists(atPath: imageDomainModel.cachedLocalAssetURL().path) {
            locallyLoadImage(imageDomainModel, completionHandler: completionHandler)
        } else {
            remotelyLoadImage(imageDomainModel, completionHandler: completionHandler)
        }
    }
    
    func cancelLoadingImage(_ imageDomainModel: ImageDomainModel) {
        assetDownloadSession.cancelDownload(url: imageDomainModel.url)
    }
    
    // MARK: - Asset
    
    private func locallyLoadImage(_ imageDomainModel: ImageDomainModel,
                                  completionHandler: @escaping ((_ result: Result<LoadImageResult, Error>) -> ())) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: imageDomainModel.cachedLocalAssetURL().path))
            
            guard let image = UIImage(data: data) else {
                completionHandler(.failure(NetworkingError.invalidData(underlyingError: nil)))
                return
            }
            
            let loadResult = LoadImageResult(imageDomainModel: imageDomainModel, image: image)
            let dataRequestResult = Result<LoadImageResult, Error>.success(loadResult)
            
            DispatchQueue.main.async {
                completionHandler(dataRequestResult)
            }
        } catch {
            remotelyLoadImage(imageDomainModel, completionHandler: completionHandler)
        }
    }
    
    private func remotelyLoadImage(_ imageDomainModel: ImageDomainModel,
                                   completionHandler: @escaping ((_ result: Result<LoadImageResult, Error>) -> ())) {
        
        assetDownloadSession.scheduleDownload(url: imageDomainModel.url) { (result) in
            switch result {
            case .success(let data):
                guard let image = UIImage(data: data) else {
                    completionHandler(.failure(NetworkingError.invalidData(underlyingError: nil)))
                    return
                }
                
                do {
                    try data.write(to: imageDomainModel.cachedLocalAssetURL(), options: .atomic)
                } catch let error {
                    completionHandler(.failure(NetworkingError.invalidData(underlyingError: error)))
                    return
                }
                
                let loadResult = LoadImageResult(imageDomainModel: imageDomainModel, image: image)
                let dataRequestResult = Result<LoadImageResult, Error>.success(loadResult)
                
                DispatchQueue.main.async {
                    completionHandler(dataRequestResult)
                }
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
}

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

protocol AssetService {
    func loadImage(_ imageDomainModel: ImageDomainModel,
                   callbackQueue: DispatchQueue,
                   completionHandler: @escaping ((_ result: Result<LoadImageResult, Error>) -> ()))
    func cancelLoadingImage(_ imageDomainModel: ImageDomainModel)
}

final class DefaultAssetService: AssetService {
    private let session = AssetDownloadsSession.shared
    private let fileManager = FileManager.default
    
    // MARK: - Load
    
    func loadImage(_ imageDomainModel: ImageDomainModel,
                   callbackQueue: DispatchQueue,
                   completionHandler: @escaping ((_ result: Result<LoadImageResult, Error>) -> ())) {
        if fileManager.fileExists(atPath: imageDomainModel.cachedLocalAssetURL().path) {
            locallyLoadImage(imageDomainModel, callbackQueue: callbackQueue, completionHandler: completionHandler)
        } else {
            remotelyLoadImage(imageDomainModel, callbackQueue: callbackQueue, completionHandler: completionHandler)
        }
    }
    
    private func locallyLoadImage(_ imageDomainModel: ImageDomainModel,
                                  callbackQueue: DispatchQueue,
                                  completionHandler: @escaping ((_ result: Result<LoadImageResult, Error>) -> ())) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: imageDomainModel.cachedLocalAssetURL().path))
            
            guard let image = UIImage(data: data) else {
                callbackQueue.async {
                    completionHandler(.failure(NetworkingError.invalidData(underlyingError: nil)))
                }
                return
            }
            
            let loadResult = LoadImageResult(imageDomainModel: imageDomainModel, image: image)
            let dataRequestResult = Result<LoadImageResult, Error>.success(loadResult)
            
            callbackQueue.async {
                completionHandler(dataRequestResult)
            }
        } catch {
            remotelyLoadImage(imageDomainModel, callbackQueue: callbackQueue, completionHandler: completionHandler)
        }
    }
    
    private func remotelyLoadImage(_ imageDomainModel: ImageDomainModel,
                                   callbackQueue: DispatchQueue,
                                   completionHandler: @escaping ((_ result: Result<LoadImageResult, Error>) -> ())) {
        
        session.scheduleDownload(url: imageDomainModel.url) { (result) in
            switch result {
            case .success(let data):
                guard let image = UIImage(data: data) else {
                    callbackQueue.async {
                        completionHandler(.failure(NetworkingError.invalidData(underlyingError: nil)))
                    }
                    return
                }
                
                do {
                    try data.write(to: imageDomainModel.cachedLocalAssetURL(), options: .atomic)
                } catch let error {
                    callbackQueue.async {
                        completionHandler(.failure(NetworkingError.invalidData(underlyingError: error)))
                    }
                    return
                }
                
                let loadResult = LoadImageResult(imageDomainModel: imageDomainModel, image: image)
                let dataRequestResult = Result<LoadImageResult, Error>.success(loadResult)
                
                callbackQueue.async {
                    completionHandler(dataRequestResult)
                }
            case .failure(let error):
                callbackQueue.async {
                    completionHandler(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Cancel
    
    func cancelLoadingImage(_ imageDomainModel: ImageDomainModel) {
        session.cancelDownload(url: imageDomainModel.url)
    }
}

private extension ImageDomainModel {
    // MARK: - Cache
    
    func cachedLocalAssetURL() -> URL {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last!
        let fileName = "\(identifier).\(url.pathExtension)"
        
        return cacheURL.appendingPathComponent(fileName)
    }
}

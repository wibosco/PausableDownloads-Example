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
    @discardableResult
    func loadImage(_ imageDomainModel: ImageDomainModel,
                   callbackQueue: DispatchQueue,
                   completionHandler: @escaping ((_ result: Result<LoadImageResult, Error>) -> ())) -> DownloadToken?
    func cancelLoadingImage(_ downloadToken: DownloadToken)
}

final class DefaultAssetService: AssetService {
    private let session: AssetDownloadsSession
    private let fileManager: FileManager
    
    // MARK: - Init
    
    init(session: AssetDownloadsSession = DefaultAssetDownloadsSession.shared,
         fileManager: FileManager = FileManager.default) {
        self.session = session
        self.fileManager = fileManager
    }
    
    // MARK: - Load
    
    @discardableResult
    func loadImage(_ imageDomainModel: ImageDomainModel,
                   callbackQueue: DispatchQueue,
                   completionHandler: @escaping ((_ result: Result<LoadImageResult, Error>) -> ())) -> DownloadToken? {
        if fileManager.fileExists(atPath: imageDomainModel.cachedLocalAssetURL().path) {
            return locallyLoadImage(imageDomainModel, callbackQueue: callbackQueue, completionHandler: completionHandler)
        } else {
            return remotelyLoadImage(imageDomainModel, callbackQueue: callbackQueue, completionHandler: completionHandler)
        }
    }
    
    private func locallyLoadImage(_ imageDomainModel: ImageDomainModel,
                                  callbackQueue: DispatchQueue,
                                  completionHandler: @escaping ((_ result: Result<LoadImageResult, Error>) -> ())) -> DownloadToken? {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: imageDomainModel.cachedLocalAssetURL().path))
            
            guard let image = UIImage(data: data) else {
                callbackQueue.async {
                    completionHandler(.failure(NetworkingError.invalidData(underlyingError: nil)))
                }
                return nil
            }
            
            let loadResult = LoadImageResult(imageDomainModel: imageDomainModel, image: image)
            let dataRequestResult = Result<LoadImageResult, Error>.success(loadResult)
            
            callbackQueue.async {
                completionHandler(dataRequestResult)
            }
            
            return nil
        } catch {
            return remotelyLoadImage(imageDomainModel, callbackQueue: callbackQueue, completionHandler: completionHandler)
        }
    }
    
    @discardableResult
    private func remotelyLoadImage(_ imageDomainModel: ImageDomainModel,
                                   callbackQueue: DispatchQueue,
                                   completionHandler: @escaping ((_ result: Result<LoadImageResult, Error>) -> ())) -> DownloadToken {
        
        session.scheduleDownload(for: imageDomainModel.url) { (result) in
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
    
    func cancelLoadingImage(_ downloadToken: DownloadToken) {
        session.pauseDownload(downloadToken)
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

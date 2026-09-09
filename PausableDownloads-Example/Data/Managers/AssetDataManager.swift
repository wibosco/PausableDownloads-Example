//
//  AssetDataManager.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 15/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation
import UIKit

struct LoadImageResult: Equatable {
    let catImage: CatImage
    let image: UIImage
}

class AssetDataManager {
    
    private let assetDownloadSession = AssetDownloadsSession.shared
    private let fileManager = FileManager.default
    
    // MARK: - CatImage
    
    func loadImage(_ catImage: CatImage, completionHandler: @escaping ((_ result: Result<LoadImageResult, Error>) -> ())) {
        if fileManager.fileExists(atPath: catImage.cachedLocalAssetURL().path) {
            locallyLoadImage(catImage, completionHandler: completionHandler)
        } else {
            remotelyLoadImage(catImage, completionHandler: completionHandler)
        }
    }
    
    func cancelLoadingImage(_ catImage: CatImage) {
        assetDownloadSession.cancelDownload(url: catImage.url)
    }
    
    // MARK: - Asset
    
    private func locallyLoadImage(_ catImage: CatImage, completionHandler: @escaping ((_ result: Result<LoadImageResult, Error>) -> ())) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: catImage.cachedLocalAssetURL().path))
            
            guard let image = UIImage(data: data) else {
                completionHandler(.failure(NetworkingError.invalidData(underlyingError: nil)))
                return
            }
            
            let loadResult = LoadImageResult(catImage: catImage, image: image)
            let dataRequestResult = Result<LoadImageResult, Error>.success(loadResult)
            
            DispatchQueue.main.async {
                completionHandler(dataRequestResult)
            }
        } catch {
            remotelyLoadImage(catImage, completionHandler: completionHandler)
        }
    }
    
    private func remotelyLoadImage(_ catImage: CatImage, completionHandler: @escaping ((_ result: Result<LoadImageResult, Error>) -> ())) {
        
        assetDownloadSession.scheduleDownload(url: catImage.url) { (result) in
            switch result {
            case .success(let data):
                guard let image = UIImage(data: data) else {
                    completionHandler(.failure(NetworkingError.invalidData(underlyingError: nil)))
                    return
                }
                
                do {
                    try data.write(to: catImage.cachedLocalAssetURL(), options: .atomic)
                } catch let error {
                    completionHandler(.failure(NetworkingError.invalidData(underlyingError: error)))
                    return
                }
                
                let loadResult = LoadImageResult(catImage: catImage, image: image)
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

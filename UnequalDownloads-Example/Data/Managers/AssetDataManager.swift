//
//  AssetDataManager.swift
//  UnequalDownloads-Example
//
//  Created by William Boles on 15/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation
import UIKit

struct LoadAssetResult: Equatable {
    let asset: GalleryAsset
    let image: UIImage
}

class AssetDataManager {
    
    private let assetDownloadSession = AssetDownloadsSession.shared
    private let fileManager = FileManager.default
    
    // MARK: - GalleryAlbum
    
    func loadAlbumThumbnailAsset(_ asset: GalleryAsset, completionHandler: @escaping ((_ result: Result<LoadAssetResult, Error>) -> ())) {
        if fileManager.fileExists(atPath: asset.cachedLocalAssetURL().path) {
            locallyLoadAsset(asset, completionHandler: completionHandler)
        } else {
            remotelyLoadAsset(asset, immediateDownload: false, completionHandler: completionHandler)
        }
    }
    
    // MARK: - GalleryItem
    
    func loadGalleryItemAsset(_ asset: GalleryAsset, completionHandler: @escaping ((_ result: Result<LoadAssetResult, Error>) -> ())) {
        if fileManager.fileExists(atPath: asset.cachedLocalAssetURL().path) {
            locallyLoadAsset(asset, completionHandler: completionHandler)
        } else {
            remotelyLoadAsset(asset, immediateDownload: true, completionHandler: completionHandler)
        }
    }
    
    func cancelLoadingGalleryItemAsset(_ asset: GalleryAsset) {
        assetDownloadSession.cancelDownload(url: asset.url)
    }
    
    // MARK: - Asset
    
    private func locallyLoadAsset(_ asset: GalleryAsset, completionHandler: @escaping ((_ result: Result<LoadAssetResult, Error>) -> ())) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: asset.cachedLocalAssetURL().path))
            
            guard let image = UIImage(data: data) else {
                completionHandler(.failure(NetworkingError.invalidData(underlayingError: nil)))
                return
            }
            
            let loadResult = LoadAssetResult(asset: asset, image: image)
            let dataRequestResult = Result<LoadAssetResult, Error>.success(loadResult)
            
            DispatchQueue.main.async {
                completionHandler(dataRequestResult)
            }
        } catch {
            remotelyLoadAsset(asset, immediateDownload: false, completionHandler: completionHandler)
        }
    }
    
    private func remotelyLoadAsset(_ asset: GalleryAsset, immediateDownload: Bool, completionHandler: @escaping ((_ result: Result<LoadAssetResult, Error>) -> ())) {
        
        assetDownloadSession.scheduleDownload(url: asset.url, immediateDownload: immediateDownload) { (result) in
            switch result {
            case .success(let data):
                guard let image = UIImage(data: data) else {
                    completionHandler(.failure(NetworkingError.invalidData(underlayingError: nil)))
                    return
                }
                
                do {
                    try data.write(to: asset.cachedLocalAssetURL(), options: .atomic)
                } catch let error {
                    completionHandler(.failure(NetworkingError.invalidData(underlayingError: error)))
                }
                
                let loadResult = LoadAssetResult(asset: asset, image: image)
                let dataRequestResult = Result<LoadAssetResult, Error>.success(loadResult)
                
                DispatchQueue.main.async {
                    completionHandler(dataRequestResult)
                }
            case .failure(let error):
                completionHandler(.failure(error))
            }
        }
    }
}

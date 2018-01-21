//
//  AssetDataManager.swift
//  SmartMediaDownloader-Example
//
//  Created by William Boles on 15/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation
import UIKit

class AssetDataManager {
    
    private let assetDownloadManager = AssetDownloadManager.shared
    private let fileManager = FileManager.default
    
    // MARK: - GalleryAlbum
    
    func loadAlbumThumbnailAsset(_ asset: GalleryAsset, completionHandler: @escaping ((_ result: DataRequestResult<(GalleryAsset, UIImage)>) -> ())) {
        if fileManager.fileExists(atPath: asset.cachedLocalAssetURL().path) {
            locallyLoadAsset(asset, completionHandler: completionHandler)
        } else {
            remotelyLoadAsset(asset, forceDownload: false, completionHandler: completionHandler)
        }
    }
    
    // MARK: - GalleryItem
    
    func loadGalleryItemAsset(_ asset: GalleryAsset, completionHandler: @escaping ((_ result: DataRequestResult<(GalleryAsset, UIImage)>) -> ())) {
        if fileManager.fileExists(atPath: asset.cachedLocalAssetURL().path) {
            locallyLoadAsset(asset, completionHandler: completionHandler)
        } else {
            remotelyLoadAsset(asset, forceDownload: true, completionHandler: completionHandler)
        }
    }
    
    func cancelLoadingGalleryItemAsset(_ asset: GalleryAsset) {
        assetDownloadManager.cancelDownload(url: asset.url)
    }
    
    // MARK: - Asset
    
    private func locallyLoadAsset(_ asset: GalleryAsset, completionHandler: @escaping ((_ result: DataRequestResult<(GalleryAsset, UIImage)>) -> ())) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: asset.cachedLocalAssetURL().path))
            
            guard let image = UIImage(data: data) else {
                //TODO: Handler
                return
            }
            
            let imageResult = DataRequestResult<(GalleryAsset, UIImage)>.success((asset, image))
            
            DispatchQueue.main.async {
                completionHandler(imageResult)
            }
        } catch {
            remotelyLoadAsset(asset, forceDownload: false, completionHandler: completionHandler)
        }
    }
    
    private func remotelyLoadAsset(_ asset: GalleryAsset, forceDownload: Bool, completionHandler: @escaping ((_ result: DataRequestResult<(GalleryAsset, UIImage)>) -> ())) {
    
        assetDownloadManager.scheduleDownload(url: asset.url, force: forceDownload) { (result) in
            switch result {
            case .success(let data):
                guard let image = UIImage(data: data) else {
                    //TODO: Handler
                    return
                }
                
                do {
                    try data.write(to: asset.cachedLocalAssetURL(), options: .atomic)
                } catch {
                    //TODO: Handler
                }
                
                let imageResult = DataRequestResult<(GalleryAsset, UIImage)>.success((asset, image))
                
                DispatchQueue.main.async {
                    completionHandler(imageResult)
                }
            case .failure(let error):
                //TODO: Handler
                print("\(error)")
            }
        }
    }
}

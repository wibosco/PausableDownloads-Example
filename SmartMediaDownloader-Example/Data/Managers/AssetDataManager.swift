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
    
    private let assetDownloadManager = AssetDownloadManager()
    private let fileManager = FileManager.default
    
    // MARK: - GalleryAlbum
    
    func loadAsset(_ asset: Asset, completionHandler: @escaping ((_ result: DataRequestResult<(Asset, UIImage)>) -> ())) {
        if fileManager.fileExists(atPath: asset.cachedLocalAssetURL().path) {
            locallyLoadAsset(asset, completionHandler: completionHandler)
        } else {
            remotelyLoadAsset(asset, completionHandler: completionHandler)
        }
    }
    
    // MARK: - Asset
    
    private func locallyLoadAsset(_ asset: Asset, completionHandler: @escaping ((_ result: DataRequestResult<(Asset, UIImage)>) -> ())) {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: asset.cachedLocalAssetURL().path))
            
            guard let image = UIImage(data: data) else {
                //TODO: Handler
                return
            }
            
            let imageResult = DataRequestResult<(Asset, UIImage)>.success((asset, image))
            
            DispatchQueue.main.async {
                completionHandler(imageResult)
            }
        } catch {
            remotelyLoadAsset(asset, completionHandler: completionHandler)
        }
    }
    
    private func remotelyLoadAsset(_ asset: Asset, completionHandler: @escaping ((_ result: DataRequestResult<(Asset, UIImage)>) -> ())) {
    
        assetDownloadManager.scheduleDownload(url: asset.url) { (result) in
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
                
                let imageResult = DataRequestResult<(Asset, UIImage)>.success((asset, image))
                
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

//
//  AssetDownloadItemFactory.swift
//  DownloadStack-Example
//
//  Created by William Boles on 27/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

protocol AssetDownloadItemFactoryType {
    func assetDownloadItem(forURL url: URL, session: URLSessionType, immediateDownload: Bool, completionHandler: @escaping AssetDownloadItemCompletionHandler) -> AssetDownloadItemType
}

class AssetDownloadItemFactory: AssetDownloadItemFactoryType {
    
    func assetDownloadItem(forURL url: URL, session: URLSessionType, immediateDownload: Bool, completionHandler: @escaping AssetDownloadItemCompletionHandler) -> AssetDownloadItemType {
        let assetDownloadItem = AssetDownloadItem(session: session, url: url)
        assetDownloadItem.immediateDownload = immediateDownload
        assetDownloadItem.completionHandler = completionHandler
        
        return assetDownloadItem
    }
}

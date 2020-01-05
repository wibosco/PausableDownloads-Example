//
//  AssetDownloadItemFactory.swift
//  UnequalDownloads-Example
//
//  Created by William Boles on 27/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

protocol AssetDownloadItemFactoryType {
    func assetDownloadItem(forURL url: URL, session: URLSessionType, delegate: AssetDownloadItemDelegate, downloadCompletionHandler: @escaping AssetDownloadItemType.DownloadCompletionHandler) -> AssetDownloadItemType
}

class AssetDownloadItemFactory: AssetDownloadItemFactoryType {
    
    func assetDownloadItem(forURL url: URL, session: URLSessionType, delegate: AssetDownloadItemDelegate, downloadCompletionHandler: @escaping AssetDownloadItemType.DownloadCompletionHandler) -> AssetDownloadItemType {
        let assetDownloadItem = AssetDownloadItem(session: session, url: url)
        assetDownloadItem.downloadCompletionHandler = downloadCompletionHandler
        assetDownloadItem.delegate = delegate
        
        return assetDownloadItem
    }
}

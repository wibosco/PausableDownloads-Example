//
//  MockAssetDownloadItemFactory.swift
//  UnequalDownloads-ExampleTests
//
//  Created by William Boles on 28/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

@testable import UnequalDownloads_Example

class MockAssetDownloadItemFactory: AssetDownloadItemFactoryType {
    var assetDownloadItemClosure: ((_ url: URL, _ session: URLSessionType, _ delegate: AssetDownloadItemDelegate, _ downloadCompletionHandler: @escaping AssetDownloadItemType.DownloadCompletionHandler) -> ())?
    var assetDownloadItem = MockAssetDownloadItem()
    
    func assetDownloadItem(forURL url: URL, session: URLSessionType, delegate: AssetDownloadItemDelegate, downloadCompletionHandler: @escaping AssetDownloadItemType.DownloadCompletionHandler) -> AssetDownloadItemType {
        assetDownloadItemClosure?(url, session, delegate, downloadCompletionHandler)
        
        assetDownloadItem.url = url
        assetDownloadItem.downloadCompletionHandler = downloadCompletionHandler
        
        return assetDownloadItem
    }
}

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
    
    var assetDownloadItemClosure: ((_ url: URL, _ session: URLSessionType, _ immediateDownload: Bool, _ completionHandler: @escaping AssetDownloadItemCompletionHandler) -> ())?
    var assetDownloadItem = MockAssetDownloadItem()
    
    func assetDownloadItem(forURL url: URL, session: URLSessionType, immediateDownload: Bool, completionHandler: @escaping AssetDownloadItemCompletionHandler) -> AssetDownloadItemType {
        assetDownloadItemClosure?(url, session, immediateDownload, completionHandler)
        
        assetDownloadItem.url = url
        assetDownloadItem.immediateDownload = immediateDownload
        assetDownloadItem.completionHandler = completionHandler
        
        return assetDownloadItem
    }
}

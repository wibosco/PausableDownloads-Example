//
//  MockAssetDownloadItem.swift
//  UnequalDownloads-ExampleTests
//
//  Created by William Boles on 27/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

@testable import UnequalDownloads_Example

class MockAssetDownloadItem: AssetDownloadItemType {
    var completionHandler: AssetDownloadItemCompletionHandler?
    var immediateDownload: Bool = false
    var status: Status = .paused
    var url: URL = URL(string: "http://www.test.com/example")!
    var description: String = "description"
    
    var resumeClosure: (() -> ())?
    var pauseClosure: (() -> ())?
    var cancelClosure: (() -> ())?
    var doneClosure: (() -> ())?
    var coalesceClosure: ((_ otherAssetDownloadItem: AssetDownloadItemType) -> ())?
    
    func resume() {
        resumeClosure?()
    }
    
    func pause() {
        pauseClosure?()
    }
    
    func cancel() {
        cancelClosure?()
    }
    
    func done() {
        doneClosure?()
    }
    
    func coalesce(_ otherAssetDownloadItem: AssetDownloadItemType) {
        coalesceClosure?(otherAssetDownloadItem)
    }
}

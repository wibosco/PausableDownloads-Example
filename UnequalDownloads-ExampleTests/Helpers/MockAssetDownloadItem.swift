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
    var delegate: AssetDownloadItemDelegate?
    
    var isCoalescable: Bool = true
    var isResumable: Bool = true
    
    var downloadCompletionHandler: AssetDownloadItemType.DownloadCompletionHandler?
    var immediateDownload: Bool = false
    var state: State = .paused
    var url: URL = URL(string: "http://www.test.com/example")!
    var description: String = "description"
    
    var resumeClosure: (() -> ())?
    var pauseClosure: (() -> ())?
    var cancelClosure: (() -> ())?
    var doneClosure: (() -> ())?
    var hibernateClosure: (() -> ())?
    var awakenClosure: (() -> ())?
    var coalesceDownloadCompletionHandlerClosure: ((_ otherDownloadCompletionHandler: AssetDownloadItemType.DownloadCompletionHandler) -> ())?
    
    func resume() {
        state = .downloading
        resumeClosure?()
    }
    
    func pause() {
        state = .paused
        pauseClosure?()
    }
    
    func hibernate() {
        state = .hibernating
        hibernateClosure?()
    }
    
    func awaken() {
        state = .paused
        awakenClosure?()
    }
    
    func cancel() {
        state = .cancelled
        cancelClosure?()
    }
    
    func done() {
        state = .done
        doneClosure?()
    }
    
    func coalesceDownloadCompletionHandler(_ otherDownloadCompletionHandler: @escaping AssetDownloadItemType.DownloadCompletionHandler) {
        coalesceDownloadCompletionHandlerClosure?(otherDownloadCompletionHandler)
    }
}

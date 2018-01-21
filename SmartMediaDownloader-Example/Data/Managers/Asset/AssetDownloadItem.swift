//
//  AssetDownloadItem.swift
//  SmartMediaDownloader-Example
//
//  Created by William Boles on 15/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

typealias AssetDownloadItemCompletionHandler = ((_ result: DataRequestResult<Data>) -> Void)

class AssetDownloadItem {
    
    let task: URLSessionDownloadTask
    
    var completionHandler: AssetDownloadItemCompletionHandler?
    
    var forcedDownload = false
    var downloadedPercentage = 0.0
    
    // MARK: - Init
    
    init(task: URLSessionDownloadTask) {
        self.task = task
    }
    
    // MARK: - Lifecycle
    
    func pause() {
        forcedDownload = false
        task.suspend()
    }
    
    func resume() {
        task.resume()
    }
    
    func cancel() {
        task.cancel()
    }
    
    // MARK: - Meta
    
    var url: URL {
        return task.currentRequest!.url!
    }
}

extension AssetDownloadItem: Equatable {}

func ==(lhs: AssetDownloadItem, rhs: AssetDownloadItem) -> Bool {
    return lhs.task == rhs.task &&
        lhs.forcedDownload == lhs.forcedDownload
}


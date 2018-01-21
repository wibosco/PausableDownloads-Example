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
    
    // MARK: - Init
    
    init(task: URLSessionDownloadTask) {
        self.task = task
    }
    
    // MARK: - Pause
    
    func pause() {
        print("pausing download: \(task.currentRequest?.url?.absoluteString ?? "unknown")")
        task.suspend()
    }
    
    func resume() {
        print("resuming/starting download: \(task.currentRequest?.url?.absoluteString ?? "unknown")")
        task.resume()
    }
}

extension AssetDownloadItem: Equatable {}

func ==(lhs: AssetDownloadItem, rhs: AssetDownloadItem) -> Bool {
    return lhs.task == rhs.task &&
        lhs.forcedDownload == lhs.forcedDownload
}


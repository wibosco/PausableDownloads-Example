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
    
    // MARK: - Init
    
    init(task: URLSessionDownloadTask) {
        self.task = task
    }
    
    // MARK: - Pause
    
    func pause() {
        task.suspend()
    }
    
    func resume() {
        task.resume()
    }
}

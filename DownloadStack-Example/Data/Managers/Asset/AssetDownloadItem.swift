//
//  AssetDownloadItem.swift
//  DownloadStack-Example
//
//  Created by William Boles on 15/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

typealias AssetDownloadItemCompletionHandler = ((_ result: Result<Data, Error>) -> Void)

enum Status: CustomStringConvertible {
    case waiting
    case downloading
    case suspended
    case cancelled
    
    // MARK: - Description
    
    var description: String {
        switch self {
        case .waiting:
            return "Waiting"
        case .downloading:
            return "Downloading"
        case .suspended:
            return "Suspended"
        case .cancelled:
            return "Cancelled"
        }
    }
}

class AssetDownloadItem {
    
    private let task: URLSessionDownloadTaskType
    
    var completionHandler: AssetDownloadItemCompletionHandler?
    
    var forceDownload = false
    var downloadPercentageComplete = 0.0
    var status: Status = .waiting
    
    // MARK: - Init
    
    init(task: URLSessionDownloadTaskType) {
        self.task = task
    }
    
    // MARK: - Lifecycle
    
    func resume() {
        status = .downloading
        task.resume()
    }
    
    func pause() {
        status = .waiting
        forceDownload = false
        task.suspend()
    }
    
    func softCancel() {
        status = .suspended
        forceDownload = false
        task.suspend()
    }
    
    func hardCancel() {
        status = .cancelled
        forceDownload = false
        task.cancel()
    }
    
    // MARK: - Meta
    
    var url: URL {
        return task.currentRequest!.url!
    }
    
    //MARK: - Coalesce
    
    func coalesce(_ otherAssetDownloadItem: AssetDownloadItem) {
        if !forceDownload && otherAssetDownloadItem.forceDownload { //Only care about upgrading forced value to true
            forceDownload = true
        }
        
        let initalCompletionHandler = completionHandler
        
        completionHandler = { (result) in
            if let initalCompletionClosure = initalCompletionHandler {
                initalCompletionClosure(result)
            }
            
            otherAssetDownloadItem.completionHandler?(result)
        }
    }
}

extension AssetDownloadItem: Equatable {
    static func ==(lhs: AssetDownloadItem, rhs: AssetDownloadItem) -> Bool {
        return lhs.url == rhs.url
    }
}


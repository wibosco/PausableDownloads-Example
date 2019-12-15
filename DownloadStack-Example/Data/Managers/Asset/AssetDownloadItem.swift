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
    case done
    
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
        case .done:
            return "Done"
        }
    }
}

protocol AssetDownloadItemType: class {
    var completionHandler: AssetDownloadItemCompletionHandler? { get set }
    var immediateDownload: Bool { get set }
    var downloadPercentageComplete: Double { get set }
    var status: Status { get }
    var url: URL { get }
    
    func resume()
    func pause()
    func softCancel()
    func hardCancel()
    func done()
    func coalesce(_ otherAssetDownloadItem: AssetDownloadItemType)
}

class AssetDownloadItem: AssetDownloadItemType, CustomStringConvertible {

    private let task: URLSessionDownloadTaskType
    
    var completionHandler: AssetDownloadItemCompletionHandler?
    
    var immediateDownload = false
    var downloadPercentageComplete = 0.0
    private(set) var status: Status = .waiting
    
    var url: URL {
        return task.currentRequest!.url!
    }
    
    var description: String {
        let percentage = (downloadPercentageComplete * 100).rounded()
        let immediate = immediateDownload ? "Yes" : "No"
        return "URL: \(url.absoluteString), status: \(status), immeediate download: \(immediate), percentage completed: \(percentage)%"
    }
    
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
        immediateDownload = false
        task.suspend()
    }
    
    func softCancel() {
        status = .suspended
        immediateDownload = false
        task.suspend()
    }
    
    func hardCancel() {
        status = .cancelled
        immediateDownload = false
        task.cancel()
    }
    
    func done() {
        status = .done
    }
    
    //MARK: - Coalesce
    
    func coalesce(_ otherAssetDownloadItem: AssetDownloadItemType) {
        if !immediateDownload && otherAssetDownloadItem.immediateDownload { //Only care about upgrading value to true
            immediateDownload = true
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
    static func == (lhs: AssetDownloadItem, rhs: AssetDownloadItem) -> Bool {
        return lhs.url == rhs.url
    }
}

//
//  AssetDownloadItem.swift
//  UnequalDownloads-Example
//
//  Created by William Boles on 15/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation
import os

typealias AssetDownloadItemCompletionHandler = ((_ assetDownloadItem: AssetDownloadItemType, _ result: Result<Data, Error>) -> ())

enum Status: CustomStringConvertible {
    case waiting
    case downloading
    case paused
    case cancelled
    case done
    
    // MARK: - Description
    
    var description: String {
        switch self {
        case .waiting:
            return "Waiting"
        case .downloading:
            return "Downloading"
        case .paused:
            return "Paused"
        case .cancelled:
            return "Cancelled"
        case .done:
            return "Done"
        }
    }
}

protocol AssetDownloadItemType: class, CustomStringConvertible {
    var completionHandler: AssetDownloadItemCompletionHandler? { get set }
    var immediateDownload: Bool { get set }
    var status: Status { get }
    var url: URL { get }
    
    func resume()
    func pause()
    func cancel()
    func done()
    func coalesce(_ otherAssetDownloadItem: AssetDownloadItemType)
}

class AssetDownloadItem: AssetDownloadItemType {

    private let callbackQueue: OperationQueue
    private let session: URLSessionType
    
    private var resumeData: Data?
    private var downloadTask: URLSessionDownloadTaskType?
    private var observation: NSKeyValueObservation?
    
    var completionHandler: AssetDownloadItemCompletionHandler?
    
    let url: URL
    var immediateDownload: Bool
    private(set) var status: Status = .waiting

    var description: String {
        return url.absoluteString
    }
    
    // MARK: - Init
    
    init(callbackQueue: OperationQueue? = OperationQueue.current, session: URLSessionType, url: URL, immediateDownload: Bool) {
        self.callbackQueue = callbackQueue ?? OperationQueue.main
        self.session = session
        self.url = url
        self.immediateDownload = immediateDownload
    }
    
    deinit {
        observation?.invalidate()
    }
    
    // MARK: - Lifecycle
    
    func resume() {
        guard (status == .waiting || status == .paused) else {
            assertionFailure("Asset can't be resumed")
            return
        }

        status = .downloading
        
        if let resumeData = resumeData {
            os_log(.info, "Attempting to resume download task")
            downloadTask = session.downloadTask(withResumeData: resumeData, completionHandler: downloadTaskCompletionHandler)
        } else {
            os_log(.info, "Creating a new download task")
            downloadTask = session.downloadTask(with: url, completionHandler: downloadTaskCompletionHandler)
        }
        
        observation = downloadTask?.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] (progress, _) in
            os_log(.info, "Downloaded %{public}.02f%% of %{public}@", (progress.fractionCompleted * 100), self?.url.absoluteString ?? "")
        }
        
        downloadTask?.resume()
    }
    
    private func downloadTaskCompletionHandler(fileLocationURL: URL?, response: URLResponse?, error: Error?) {
        if let error = error, (error as NSError).code == NSURLErrorCancelled, self.status == .paused {
            //Download cancelled due to pausing so eat the error
            return
        }
        
        guard let fileLocationURL = fileLocationURL else {
            callbackQueue.addOperation {
                self.completionHandler?(self, .failure(NetworkingError.retrieval(underlayingError: error)))
            }
            return
        }

        do {
            let data = try Data(contentsOf: fileLocationURL)
            callbackQueue.addOperation {
                self.completionHandler?(self, .success(data))
            }
        } catch let error {
            callbackQueue.addOperation {
                self.completionHandler?(self, .failure(NetworkingError.invalidData(underlayingError: error)))
            }
            
        }
    }
    
    
    func pause() {
        status = .paused

        downloadTask?.cancel(byProducingResumeData: { [weak self] (data) in
            self?.resumeData = data
        })
        
        cleanup()
    }
    
    func cancel() {
        status = .cancelled
        
        downloadTask?.cancel()
        
        cleanup()
    }
    
    private func cleanup() {
        immediateDownload = false
        observation?.invalidate()
        downloadTask = nil
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
        
        completionHandler = { (_, result) in
            if let initalCompletionClosure = initalCompletionHandler {
                initalCompletionClosure(self, result)
            }
            
            otherAssetDownloadItem.completionHandler?(otherAssetDownloadItem, result)
        }
    }
}

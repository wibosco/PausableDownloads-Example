//
//  AssetDownloadItem.swift
//  UnequalDownloads-Example
//
//  Created by William Boles on 15/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation
import os

enum State: String {
    case downloading
    case paused
    case hibernating
    case cancelled
    case done
}

protocol AssetDownloadItemType: CustomStringConvertible {
    
    typealias DownloadCompletionHandler = ((_ result: Result<Data, Error>) -> ())
    
    var delegate: AssetDownloadItemDelegate? { get set }
    
    var downloadCompletionHandler: DownloadCompletionHandler? { get set }

    var state: State { get }
    var url: URL { get }
    var isCoalescable: Bool { get }
    var isResumable: Bool { get }
    
    func resume()
    func pause()
    func hibernate()
    func awaken()
    func cancel()
    func done()
    func coalesceDownloadCompletionHandler(_ otherDownloadCompletionHandler: @escaping DownloadCompletionHandler)
}

protocol AssetDownloadItemDelegate {
    func assetDownloadItemDone(_ assetDownloadItem: AssetDownloadItemType)
}

final class AssetDownloadItem: AssetDownloadItemType {
    
    private let callbackQueue: OperationQueue
    private let session: URLSessionType
    
    private var resumptionData: Data?
    private var downloadTask: URLSessionDownloadTaskType?
    private var observation: NSKeyValueObservation?
    
    var delegate: AssetDownloadItemDelegate?
    
    var downloadCompletionHandler: DownloadCompletionHandler?
    
    let url: URL
    private(set) var state: State = .paused

    var description: String {
        return url.absoluteString
    }
    
    var isCoalescable: Bool {
        return (state == .downloading) ||
            (state == .paused) ||
            (state == .hibernating)
    }
    
    var isResumable: Bool {
        return (state == .paused)
    }
    
    // MARK: - Init
    
    init(callbackQueue: OperationQueue? = OperationQueue.current, session: URLSessionType, url: URL) {
        self.callbackQueue = callbackQueue ?? OperationQueue.main
        self.session = session
        self.url = url
    }
    
    deinit {
        observation?.invalidate()
    }
    
    // MARK: - Lifecycle
    
    func resume() {
        guard isResumable else {
            assertionFailure("Asset can't be resumed")
            return
        }

        state = .downloading
        
        let completionHandler: ((_ fileLocationURL: URL?, _ response: URLResponse?, _ error: Error?) -> ()) = { (fileLocationURL, response, error) in
            if let error = error, (error as NSError).code == NSURLErrorCancelled, (self.state == .paused || self.state == .hibernating) {
                //Download cancelled due to being paused so lets eat this error
                return
            }
            
            guard let fileLocationURL = fileLocationURL else {
                self.callbackQueue.addOperation {
                    self.downloadCompletionHandler?(.failure(NetworkingError.retrieval(underlayingError: error)))
                }
                self.done()
                return
            }

            do {
                let data = try Data(contentsOf: fileLocationURL)
                self.callbackQueue.addOperation {
                    self.downloadCompletionHandler?(.success(data))
                }
            } catch let error {
                self.callbackQueue.addOperation {
                    self.downloadCompletionHandler?(.failure(NetworkingError.invalidData(underlayingError: error)))
                }
            }
            
            self.done()
        }
        
        if let resumptionData = resumptionData {
            os_log(.info, "Attempting to resume download task")
            downloadTask = session.downloadTask(withResumeData: resumptionData, completionHandler: completionHandler)
        } else {
            os_log(.info, "Creating a new download task")
            downloadTask = session.downloadTask(with: url, completionHandler: completionHandler)
        }
        
        observation = downloadTask?.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] (progress, change) in
            os_log(.info, "Downloaded %{public}.02f%% of %{public}@", (progress.fractionCompleted * 100), self?.url.absoluteString ?? "")
        }
        
        downloadTask?.resume()
    }
    
    func pause() {
        state = .paused
        
        cancelAndSaveData()
    }
    
    func hibernate() {
        state = .hibernating
        
        cancelAndSaveData()
    }
    
    func awaken() {
        state = .paused
    }
    
    private func cancelAndSaveData() {
        downloadTask?.cancel(byProducingResumeData: { [weak self] (data) in
            guard let data = data else {
                return
            }
            
            os_log(.info, "Cancelled download task has produced resumption data of: %{public}@ for %{public}@", data.description, self?.url.absoluteString ?? 0)
            self?.resumptionData = data
        })
        
        cleanup()
    }
    
    func cancel() {
        state = .cancelled
        
        downloadTask?.cancel()
        
        cleanup()
    }
    
    func done() {
        state = .done
        
        callbackQueue.addOperation {
            self.delegate?.assetDownloadItemDone(self)
        }
        
        cleanup()
    }
    
    private func cleanup() {
        observation?.invalidate()
        downloadTask = nil
    }
    
    //MARK: - Coalesce
    
    func coalesceDownloadCompletionHandler(_ otherDownloadCompletionHandler: @escaping DownloadCompletionHandler) {
        let initalDownloadCompletionHandler = downloadCompletionHandler

        downloadCompletionHandler = { result in
            initalDownloadCompletionHandler?(result)
            otherDownloadCompletionHandler(result)
        }
    }
    
    // MARK: - Equatable
    
    static func == (lhs: AssetDownloadItem, rhs: AssetDownloadItem) -> Bool {
        return lhs.url == rhs.url
    }
}

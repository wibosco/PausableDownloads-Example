//
//  AssetDownloadsSession.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 14/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import UIKit
import os

protocol NotificationCenterType {
    @discardableResult
    func addObserver(forName name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?, using block: @escaping (Notification) -> Void) -> NSObjectProtocol
}

extension NotificationCenter: NotificationCenterType { }

class AssetDownloadsSession: NSObject, AssetDownloadItemDelegate, URLSessionDownloadDelegate {
    
    private var assetDownloadItems = [AssetDownloadItem]()
    private let accessQueue = DispatchQueue(label: "com.williamboles.downloadssession")
    private var session: URLSessionType!
    
    // MARK: - Singleton
    
    static let shared = AssetDownloadsSession()
    
    // MARK: - Init
    
    init(urlSessionFactory: URLSessionFactoryType = URLSessionFactory(), notificationCenter: NotificationCenterType = NotificationCenter.default) {
        super.init()
        
        self.session = urlSessionFactory.defaultSession(delegate: self)
        registerForNotifications(on: notificationCenter)
    }
    
    // MARK: - Notification
    
    private func registerForNotifications(on notificationCenter: NotificationCenterType) {
        notificationCenter.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { [weak self] _ in
            self?.purgePausedDownloads()
        }
    }
    
    private func purgePausedDownloads() {
        accessQueue.sync {
            os_log(.info, "Cancelling paused items")
            
            assetDownloadItems = assetDownloadItems.filter { (assetDownloadItem) -> Bool in
                let isPaused = assetDownloadItem.isPaused
                if isPaused {
                    assetDownloadItem.cancel()
                }
                
                return !isPaused
            }
        }
    }
    
    // MARK: - Schedule
    
    func scheduleDownload(url: URL, completionHandler: @escaping DownloadCompletionHandler) {
        accessQueue.sync {
            if let assetDownloadItem = assetDownloadItems.first(where: { $0.url == url && $0.isCoalescable }) {
                os_log(.info, "Found existing %{public}@ download so coalescing them for: %{public}@", assetDownloadItem.state.rawValue, assetDownloadItem.description)
                
                assetDownloadItem.coalesceDownloadCompletionHandler(completionHandler)
                
                if assetDownloadItem.isResumable {
                    assetDownloadItem.resume()
                }
            } else {
                let assetDownloadItem = AssetDownloadItem(session: session, url: url)
                assetDownloadItem.downloadCompletionHandler = completionHandler
                assetDownloadItem.delegate = self
                
                os_log(.info, "Created a new download: %{public}@", assetDownloadItem.description)
                
                assetDownloadItems.append(assetDownloadItem)
                
                assetDownloadItem.resume()
            }
        }
    }
    
    // MARK: - Cancel
    
    func cancelDownload(url: URL) {
        accessQueue.sync {
            guard let assetDownloadItem = assetDownloadItems.first(where: { $0.url == url }) else {
                return
            }
            
            os_log(.info, "Download: %{public}@ going to paused", assetDownloadItem.description)
            assetDownloadItem.pause()
        }
    }
    
    // MARK: - AssetDownloadItemDelegate
    
    fileprivate func assetDownloadItemCompleted(_ assetDownloadItem: AssetDownloadItem) {
        accessQueue.sync {
            os_log(.info, "Completed download of: %{public}@", assetDownloadItem.description)
            
            if let index = assetDownloadItems.firstIndex(where: { $0.url == assetDownloadItem.url && $0.isCompleted }) {
                assetDownloadItems.remove(at: index)
            }
        }
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) { /*no-op*/ }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64, expectedTotalBytes: Int64) {
        guard let url = downloadTask.currentRequest?.url else {
            return
        }
        let resumptionPercentage = (Double(fileOffset)/Double(expectedTotalBytes)) * 100
        os_log(.info, "Resuming download: %{public}@ from: %{public}.02f%%", url.absoluteString, resumptionPercentage)
    }
}

fileprivate enum State: String {
    case ready
    case downloading
    case paused
    case cancelled
    case completed
}

fileprivate protocol AssetDownloadItemDelegate {
    func assetDownloadItemCompleted(_ assetDownloadItem: AssetDownloadItem)
}

typealias DownloadCompletionHandler = ((_ result: Result<Data, Error>) -> ())

fileprivate class AssetDownloadItem {
    
    private let session: URLSessionType
    private var resumptionData: Data?
    private var downloadTask: URLSessionDownloadTaskType?
    private var observation: NSKeyValueObservation?
    
    var delegate: AssetDownloadItemDelegate?
    var downloadCompletionHandler: DownloadCompletionHandler?
    let url: URL
    private(set) var state: State = .ready
    
    var description: String {
        return url.absoluteString
    }
    
    var isCoalescable: Bool {
        return (state == .ready) ||
            (state == .downloading) ||
            (state == .paused)
    }
    
    var isResumable: Bool {
        return (state == . ready) ||
            (state == .paused)
    }
    
    var isPaused: Bool {
        return state == .paused
    }
    
    var isCompleted: Bool {
        return state == .completed
    }
    
    // MARK: - Init
    
    init(session: URLSessionType, url: URL) {
        self.session = session
        self.url = url
    }
    
    deinit {
        observation?.invalidate()
    }
    
    // MARK: - Lifecycle
    
    func resume() {
        state = .downloading
        
        if let resumptionData = resumptionData {
            os_log(.info, "Attempting to resume download task")
            downloadTask = session.downloadTask(withResumeData: resumptionData, completionHandler: handleDownloadTaskComplete)
        } else {
            os_log(.info, "Creating a new download task")
            downloadTask = session.downloadTask(with: url, completionHandler: handleDownloadTaskComplete)
        }
        
        observation = downloadTask?.progress.observe(\.fractionCompleted, options: [.new]) { [weak self] (progress, change) in
            os_log(.info, "Downloaded %{public}.02f%% of %{public}@", (progress.fractionCompleted * 100), self?.url.absoluteString ?? "")
        }
        
        downloadTask?.resume()
    }
    
    private func handleDownloadTaskComplete(_ fileLocationURL: URL?, _ response: URLResponse?, _ error: Error?) {
        var result: Result<Data, Error>
        defer {
            downloadCompletionHandler?(result)
            
            /* A paused download triggers its URLSessionDownloadTask instances
             completion closure but we don't consider this AssetDownloadItem
             instance complete until it has either finished downloading (data or
             error) or been cancelled. So we need to suppress the call to
             `complete()` here for paused downloads.
             */
            if !isPaused {
                complete()
            }
            
            cleanup()
        }
        
        guard let fileLocationURL = fileLocationURL else {
            result = .failure(NetworkingError.retrieval(underlayingError: error))
            return
        }
        
        do {
            let data = try Data(contentsOf: fileLocationURL)
            result = .success(data)
        } catch let error {
            result = .failure(NetworkingError.invalidData(underlayingError: error))
        }
    }
    
    func pause() {
        state = .paused
        
        cancelAndSaveData()
    }
    
    private func cancelAndSaveData() {
        downloadTask?.cancel(byProducingResumeData: { [weak self] (data) in
            guard let data = data else {
                return
            }
            
            os_log(.info, "Cancelled download task has produced resumption data of: %{public}@ for %{public}@", data.description, self?.url.absoluteString ?? "unknown url")
            self?.resumptionData = data
        })
    }
    
    func cancel() {
        state = .cancelled
        
        downloadTask?.cancel()
    }
    
    private func complete() {
        state = .completed
        
        delegate?.assetDownloadItemCompleted(self)
    }
    
    private func cleanup() {
        observation?.invalidate()
        downloadTask = nil
        downloadCompletionHandler = nil
    }
    
    //MARK: - Coalesce
    
    func coalesceDownloadCompletionHandler(_ otherDownloadCompletionHandler: @escaping DownloadCompletionHandler) {
        let initalDownloadCompletionHandler = downloadCompletionHandler
        
        downloadCompletionHandler = { result in
            initalDownloadCompletionHandler?(result)
            otherDownloadCompletionHandler(result)
        }
    }
}


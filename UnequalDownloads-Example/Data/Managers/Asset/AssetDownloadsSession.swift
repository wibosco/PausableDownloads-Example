//
//  AssetDownloadsSession.swift
//  UnequalDownloads-Example
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
        notificationCenter.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { _ in
            self.accessQueue.sync {
                os_log(.info, "Cancelling paused items")
                
                self.assetDownloadItems = self.assetDownloadItems.filter { (assetDownloadItem) -> Bool in
                    let isPaused = assetDownloadItem.state == .paused
                    if isPaused {
                        assetDownloadItem.cancel()
                    }
                    
                    return !isPaused
                }
            }
        }
    }
    
    // MARK: - Schedule
    
    func scheduleDownload(url: URL, completionHandler: @escaping DownloadCompletionHandler) {
        accessQueue.sync {
            if let existingCoalescableAssetDownloadItem = coalescableAssetDownloadItem(withURL: url) {
                os_log(.info, "Found existing %{public}@ download so coalescing them for: %{public}@", existingCoalescableAssetDownloadItem.state.rawValue, existingCoalescableAssetDownloadItem.description)
                existingCoalescableAssetDownloadItem.coalesceDownloadCompletionHandler(completionHandler)
                
                if existingCoalescableAssetDownloadItem.isResumable {
                    existingCoalescableAssetDownloadItem.resume()
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
    
    // MARK: - Search
    
    private func coalescableAssetDownloadItem(withURL url: URL) -> AssetDownloadItem? {
        return assetDownloadItems.first { $0.url == url && $0.isCoalescable }
    }
    
    // MARK: - AssetDownloadItemDelegate
    
    fileprivate func assetDownloadItemDone(_ assetDownloadItem: AssetDownloadItem) {
        accessQueue.sync {
            os_log(.info, "Finished download of: %{public}@", assetDownloadItem.description)
            
            if let index = assetDownloadItems.firstIndex(of: assetDownloadItem) {
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
    case done
}

fileprivate protocol AssetDownloadItemDelegate {
    func assetDownloadItemDone(_ assetDownloadItem: AssetDownloadItem)
}

typealias DownloadCompletionHandler = ((_ result: Result<Data, Error>) -> ())

fileprivate class AssetDownloadItem: Equatable {
    
    private let callbackQueue: OperationQueue
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
        state = .downloading
        
        let completionHandler: ((_ fileLocationURL: URL?, _ response: URLResponse?, _ error: Error?) -> ()) = { [weak self] (fileLocationURL, response, error) in
            guard let fileLocationURL = fileLocationURL else {
                self?.callbackQueue.addOperation {
                    self?.downloadCompletionHandler?(.failure(NetworkingError.retrieval(underlayingError: error)))
                }
                self?.done()
                return
            }
            
            do {
                let data = try Data(contentsOf: fileLocationURL)
                self?.callbackQueue.addOperation {
                    self?.downloadCompletionHandler?(.success(data))
                }
            } catch let error {
                self?.callbackQueue.addOperation {
                    self?.downloadCompletionHandler?(.failure(NetworkingError.invalidData(underlayingError: error)))
                }
            }
            
            self?.done()
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


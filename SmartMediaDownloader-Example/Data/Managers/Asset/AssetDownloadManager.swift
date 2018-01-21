//
//  AssetDownloadManager.swift
//  SmartMediaDownloader-Example
//
//  Created by William Boles on 16/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

class AssetDownloadManager: NSObject {
    
    lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: UUID().uuidString)
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
        return session
    }()
    
    private var waitingStack = AssetDownloadStack()
    private var executingQueue = [AssetDownloadItem]()
    
    private static let maximumConcurrentDownloadsResetValue = 4
    
    var maximumConcurrentDownloads = AssetDownloadManager.maximumConcurrentDownloadsResetValue {
        didSet {
            if maximumConcurrentDownloads != oldValue {
                print("set maximum concurrent downloads to \(maximumConcurrentDownloads)")
            }
        }
    }
    
    // MARK: - Singleton
    
    static let shared = AssetDownloadManager()
    
    // MARK: - Download
    
    private func download(url: URL, force: Bool, completionHandler: @escaping AssetDownloadItemCompletionHandler) {
        if force {
            pauseDownloads()
        }
        
        let downloadTask = urlSession.downloadTask(with: url)
        let assetDownloadItem = AssetDownloadItem(task: downloadTask)
        assetDownloadItem.completionHandler = completionHandler
        assetDownloadItem.forcedDownload = force
        
        waitingStack.push(assetDownloadItem: assetDownloadItem, forceDownload: false)
        
        resumeDownloads()
    }
    
    func scheduleDownload(url: URL, force: Bool, completionHandler: @escaping AssetDownloadItemCompletionHandler) {
        print("\(url.absoluteString) has force value: \(force)")
        download(url: url, force: force, completionHandler: completionHandler)
    }
    
    // MARK: - Download
    
    private func pauseDownloads() {
        print("going to pause executing downloads: \(executingQueue.count) and add them to already waiting stack: \(waitingStack.count)")
        
        for downloadTask in executingQueue.reversed() {
            downloadTask.pause()
            waitingStack.push(assetDownloadItem: downloadTask)
        }
        
        executingQueue.removeAll()
    }
    
    private func resumeDownloads() {
        updatedConcurrentDownloadLimitIfNeeded()
        
        for _ in executingQueue.count..<maximumConcurrentDownloads {
            guard let assetDownloadItem = waitingStack.pop() else {
                return
            }
            
            executingQueue.append(assetDownloadItem)
            print("executing queue has \(executingQueue.count) item(s)")
            assetDownloadItem.resume()
        }
    }
    
    func updatedConcurrentDownloadLimitIfNeeded() {
        guard let assetDownloadItem = waitingStack.peek() else {
            maximumConcurrentDownloads = AssetDownloadManager.maximumConcurrentDownloadsResetValue
            return
        }
        
        if assetDownloadItem.forcedDownload {
            maximumConcurrentDownloads = 1
        } else {
            maximumConcurrentDownloads = AssetDownloadManager.maximumConcurrentDownloadsResetValue
        }
    }
    
    // MARK: - Executing
    
    func executingAssetDownloadItem(for downloadTask: URLSessionDownloadTask) -> AssetDownloadItem? {
        for assetDownloadItem in executingQueue {
            if assetDownloadItem.task == downloadTask {
                return assetDownloadItem
            }
        }
        
        return nil
    }
}

extension AssetDownloadManager: URLSessionDownloadDelegate {
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        maximumConcurrentDownloads = AssetDownloadManager.maximumConcurrentDownloadsResetValue
        
        guard let executingAssetDownloadItem = executingAssetDownloadItem(for: downloadTask), let index = self.executingQueue.index(of: executingAssetDownloadItem)  else {
            return
        }
        
        self.executingQueue.remove(at: index)
        self.resumeDownloads()
        
        print("completed download of \(executingAssetDownloadItem.task.currentRequest?.url?.absoluteString ?? "unknown")")
        
        do {
            let data = try Data(contentsOf: location)
            
            executingAssetDownloadItem.completionHandler?(.success(data))
        } catch {
            //TODO: Handle exception
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let executingAssetDownloadItem = executingAssetDownloadItem(for: downloadTask)  else {
            return
        }
        
        let percentageComplete = Double(totalBytesWritten)/Double(totalBytesExpectedToWrite)
        
        print("downloading \(executingAssetDownloadItem.task.currentRequest?.url?.absoluteString ?? "unknown") percentage complete: \(percentageComplete)")
        
        //TODO: Trigger callback
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        //TODO: Trigger callback
    }
}

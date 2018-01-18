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
    
    private let waitingStack = AssetDownloadStack()
    private var executingQueue = [AssetDownloadItem]()
    
    let maximumConcurrentDownloads: Int
    
    // MARK: - Init
    
    init(maximumConcurrentDownloads: Int = 1) {
        self.maximumConcurrentDownloads = maximumConcurrentDownloads
    }
    
    // MARK: - Download
    
    private func download(url: URL, force: Bool, completionHandler: @escaping AssetDownloadItemCompletionHandler) {
        if force {
            pauseDownloads()
        }
        
        let downloadTask = urlSession.downloadTask(with: url)
        let assetDownloadItem = AssetDownloadItem(task: downloadTask)
        assetDownloadItem.completionHandler = completionHandler
        
        waitingStack.push(assetDownloadItem: assetDownloadItem, forceDownload: false)
        
        resumeDownloads()
    }
    
    func scheduleDownload(url: URL, completionHandler: @escaping AssetDownloadItemCompletionHandler) {
        download(url: url, force: false, completionHandler: completionHandler)
    }
    
    func forceDownload(url: URL, completionHandler: @escaping AssetDownloadItemCompletionHandler) {
        download(url: url, force: true, completionHandler: completionHandler)
    }
    
    // MARK: - Download
    
    private func pauseDownloads() {
        for downloadTask in executingQueue.reversed() {
            downloadTask.pause()
            waitingStack.push(assetDownloadItem: downloadTask)
        }
        
        executingQueue.removeAll()
    }
    
    private func resumeDownloads() {
        for _ in 0..<maximumConcurrentDownloads {
            guard let assetDownloadItem = waitingStack.pop() else {
                return
            }
            
            executingQueue.append(assetDownloadItem)
            assetDownloadItem.resume()
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
        guard let executingAssetDownloadItem = executingAssetDownloadItem(for: downloadTask)  else {
            return
        }
            
        do {
            let data = try Data(contentsOf: location)
            
            executingAssetDownloadItem.completionHandler?(.success(data))
        } catch {
            //TODO: Handle exception
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        //TODO: Trigger callback
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        //TODO: Trigger callback
    }
}

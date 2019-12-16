//
//  AssetDownloadManager.swift
//  DownloadStack-Example
//
//  Created by William Boles on 16/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import UIKit
import os

class AssetDownloadManager: NSObject, URLSessionDownloadDelegate {

    private var session: URLSessionType!
    private let assetDownloadsSession: AssetDownloadsSession

    // MARK: - Singleton
    
    static let shared = AssetDownloadManager()
    
    // MARK: - Init
    
    init(urlSessionFactory: URLSessionFactoryType = URLSessionFactory(), assetDownloadsSession: AssetDownloadsSession = AssetDownloadsSession()) {
        self.assetDownloadsSession = assetDownloadsSession
        
        super.init()
            
        self.session = urlSessionFactory.defaultSession(delegate: self, delegateQueue: nil)
    }
    
    // MARK: - Download
    
    func scheduleDownload(url: URL, forceDownload: Bool, completionHandler: @escaping AssetDownloadItemCompletionHandler) {
        if forceDownload {
            assetDownloadsSession.pauseAllDownloads()
        }
        
        let assetDownloadItem = createAssetDownloadItem(forURL: url, forceDownload: forceDownload, completionHandler: completionHandler)
        assetDownloadsSession.insert(assetDownloadItem: assetDownloadItem)
        
        assetDownloadsSession.startDownloads()
    }
    
    private func createAssetDownloadItem(forURL url: URL, forceDownload: Bool, completionHandler: @escaping AssetDownloadItemCompletionHandler) -> AssetDownloadItem {
        let downloadTask = session.downloadTask(with: url)
        let assetDownloadItem = AssetDownloadItem(task: downloadTask)
        assetDownloadItem.completionHandler = completionHandler
        assetDownloadItem.immediateDownload = forceDownload
        
        return assetDownloadItem
    }
    
    // MARK: - Cancel
    
    func cancelDownload(url: URL) {
        assetDownloadsSession.cancelDownload(url: url)
        assetDownloadsSession.startDownloads()
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let assetDownloadItem = assetDownloadsSession.assetDownloadItem(withURLSessionTask: downloadTask) else {
            return
        }
        
        let percentageComplete = Double(totalBytesWritten)/Double(totalBytesExpectedToWrite)
        assetDownloadItem.downloadPercentageComplete = percentageComplete
        
        os_log(.info, "Downloaded some of: %{public}@", assetDownloadItem.description)
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let assetDownloadItem = assetDownloadsSession.assetDownloadItem(withURLSessionTask: downloadTask) else {
            return
        }
        
        assetDownloadsSession.finishedDownload(ofAssetDownloadItem: assetDownloadItem)
        assetDownloadsSession.startDownloads()
        
        do {
            let data = try Data(contentsOf: location)
            
            assetDownloadItem.completionHandler?(.success(data))
        } catch {
            assetDownloadItem.completionHandler?(.failure(APIError.invalidData))
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let assetDownloadItem = assetDownloadsSession.assetDownloadItem(withURLSessionTask: task) else {
            return
        }
        
        assetDownloadsSession.finishedDownload(ofAssetDownloadItem: assetDownloadItem)
        assetDownloadsSession.startDownloads()
        
        guard let error = error else {
            assetDownloadItem.completionHandler?(.failure(APIError.unknown))
            return
        }
        
        assetDownloadItem.completionHandler?(.failure(error))
    }
}

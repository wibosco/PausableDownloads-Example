//
//  AssetDownloadManager.swift
//  DownloadStack-Example
//
//  Created by William Boles on 16/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import UIKit

private enum DownloadingMode: CustomStringConvertible {
    case single
    case multiple
    
    // MARK: - Description
    
    var description: String {
         switch self {
         case .single:
             return "Single"
         case .multiple:
             return "Multiple"
         }
     }
}

protocol NotificationCenterType {
    @discardableResult
    func addObserver(forName name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?, using block: @escaping (Notification) -> Void) -> NSObjectProtocol
}

extension NotificationCenter: NotificationCenterType { }

class AssetDownloadManager: NSObject {
    
    private var downloading = [AssetDownloadItem]()
    private var waiting = [AssetDownloadItem]()
    private var cancelled = [AssetDownloadItem]()
    
    private let notificationCenter: NotificationCenterType
    private var session: URLSessionType!
    
    private var downloadingMode: DownloadingMode {
        if (downloading.first?.forceDownload ?? false) || (waiting.last?.forceDownload ?? false) {
            return .single
        }
        
        return .multiple
    }
    
    var shouldGenerateReport = false

    // MARK: - Singleton
    
    static let shared = AssetDownloadManager()
    
    // MARK: - Init
    
    init(urlSessionFactory: URLSessionFactoryType = URLSessionFactory(), notificationCenter: NotificationCenterType = NotificationCenter.default) {
        self.notificationCenter = notificationCenter
        
        super.init()
            
        self.session = urlSessionFactory.defaultSession(delegate: self, delegateQueue: nil)
        
        registerForNotifications()
    }
    
    // MARK: - Notification
    
    private func registerForNotifications() {
        notificationCenter.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { _ in
            self.hardCancellSoftCancelledDownloads()
        }
    }
    
    private func hardCancellSoftCancelledDownloads() {
        for downloadAssetItem in cancelled {
            downloadAssetItem.hardCancel()
        }
        
        cancelled.removeAll()
    }
    
    // MARK: - Download
    
    func scheduleDownload(url: URL, forceDownload: Bool, completionHandler: @escaping AssetDownloadItemCompletionHandler) {
        download(url: url, forceDownload: forceDownload, completionHandler: completionHandler)
    }
    
    private func download(url: URL, forceDownload: Bool, completionHandler: @escaping AssetDownloadItemCompletionHandler) {
        if forceDownload {
            pauseDownloads()
        }
        
        let assetDownloadItem = createAssetDownloadItem(forURL: url, forceDownload: forceDownload, completionHandler: completionHandler)
        
        if let (_, existingAssetDownloadItem) = downloadingAssetDownloadItem(withURL: url) {
            existingAssetDownloadItem.coalesce(assetDownloadItem)
        } else if let (_, existingAssetDownloadItem) = waitingAssetDownloadItem(withURL: url) {
            existingAssetDownloadItem.coalesce(assetDownloadItem)
            // Move download item to the front of the waiting stack
            moveAssetDownloadItemToFrontOfWaiting(assetDownloadItem)
        } else if let (_, existingAssetDownloadItem) = cancelledAssetDownloadItem(withURL: url) {
            //as the download was cancelled no need to coalesce - just override
            existingAssetDownloadItem.completionHandler = completionHandler
            existingAssetDownloadItem.forceDownload = forceDownload
            
            // Add to front of waiting stack
            transferFromCancelledToWaiting(assetDownloadItem: existingAssetDownloadItem)
        } else {
            // Add to front of waiting stack
            waiting.append(assetDownloadItem)
        }
    
        resumePausedDownloads()
    }
    
    private func createAssetDownloadItem(forURL url: URL, forceDownload: Bool, completionHandler: @escaping AssetDownloadItemCompletionHandler) -> AssetDownloadItem {
        let downloadTask = session.downloadTask(with: url)
        let assetDownloadItem = AssetDownloadItem(task: downloadTask)
        assetDownloadItem.completionHandler = completionHandler
        assetDownloadItem.forceDownload = forceDownload
        
        return assetDownloadItem
    }

    // MARK: - Pause
    
    private func pauseDownloads() {
        for assetDownloadItem in downloading.reversed() {
            assetDownloadItem.pause()
            
            transFromDownloadingToPaused(assetDownloadItem: assetDownloadItem)
        }
    }
    
    // MARK: - Resume
    
    private func resumePausedDownloads() {
        switch downloadingMode {
        case .multiple:
            let assetDownloadItems = waiting.reversed() as [AssetDownloadItem]
            resumePausedDownloads(forAssetDownloadItems: assetDownloadItems)
            waiting.removeAll()
        case .single:
            if let assetDownloadItem = waiting.last {
                resumePausedDownloads(forAssetDownloadItems: [assetDownloadItem])
                waiting.removeLast()
            }
        }
        
        generateReport()
    }
    
    private func resumePausedDownloads(forAssetDownloadItems assetDownloadItems: [AssetDownloadItem]) {
        for assetDownloadItem in assetDownloadItems {
            downloading.append(assetDownloadItem)
            assetDownloadItem.resume()
        }
    }
    
    // MARK: - Transfer
    
    private func transFromDownloadingToPaused(assetDownloadItem: AssetDownloadItem) {
        guard let index = downloading.firstIndex(of: assetDownloadItem) else {
            return
        }
        
        downloading.remove(at: index)
        waiting.append(assetDownloadItem)
    }
    
    private func transferFromWaitingToDownloading(assetDownloadItem: AssetDownloadItem) {
        guard let index = waiting.firstIndex(of: assetDownloadItem) else {
            return
        }
        
        waiting.remove(at: index)
        downloading.append(assetDownloadItem)
    }
    
    private func transferFromCancelledToWaiting(assetDownloadItem: AssetDownloadItem) {
        guard let index = cancelled.firstIndex(of: assetDownloadItem) else {
            return
        }
        
        cancelled.remove(at: index)
        waiting.append(assetDownloadItem)
    }
    
    private func moveAssetDownloadItemToFrontOfWaiting(_ assetDownloadItem: AssetDownloadItem) {
        guard let index = waiting.firstIndex(of: assetDownloadItem) else {
            return
        }
        
        waiting.remove(at: index)
        waiting.append(assetDownloadItem)
    }
    
    // MARK: - Cancel
    
    func cancelDownload(url: URL) {
        var assetDownloadItemToBeSuspended: AssetDownloadItem?
        
        if let (index, assetDownloadItem) = downloadingAssetDownloadItem(withURL: url) {
            assetDownloadItemToBeSuspended = assetDownloadItem
            downloading.remove(at: index)
        } else if let (index, assetDownloadItem) = waitingAssetDownloadItem(withURL: url) {
            assetDownloadItemToBeSuspended = assetDownloadItem
            waiting.remove(at: index)
        }
        
        if let assetDownloadItem = assetDownloadItemToBeSuspended {
            assetDownloadItem.softCancel()
            cancelled.append(assetDownloadItem)
        }
        
        generateReport()
        
        resumePausedDownloads()
    }
    
    // MARK: - Search
    
    private func assetDownloadItem(withURL url: URL, in assetDownloadItems: [AssetDownloadItem]) -> (Int, AssetDownloadItem)? {
        for (index, assetDownloadItem) in assetDownloadItems.enumerated() {
            if assetDownloadItem.url == url {
                return (index, assetDownloadItem)
            }
        }
        
        return nil
    }
    
    private func waitingAssetDownloadItem(withURL url: URL) -> (Int, AssetDownloadItem)? {
        return assetDownloadItem(withURL: url, in: waiting)
    }
    
    private func downloadingAssetDownloadItem(withURL url: URL) -> (Int, AssetDownloadItem)? {
        return assetDownloadItem(withURL: url, in: downloading)
    }
    
    private func cancelledAssetDownloadItem(withURL url: URL) -> (Int, AssetDownloadItem)? {
        return assetDownloadItem(withURL: url, in: cancelled)
    }
    
    private func downloadingAssetDownloadItem(withURLSessionTask sessionTask: URLSessionTask) -> (Int, AssetDownloadItem)? {
        guard let url = sessionTask.currentRequest?.url else {
            return nil
        }
        
        return assetDownloadItem(withURL: url, in: downloading)
    }
}

extension AssetDownloadManager: URLSessionDownloadDelegate {
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let (_, assetDownloadItem) = downloadingAssetDownloadItem(withURLSessionTask: downloadTask)  else {
            return
        }
        
        let percentageComplete = Double(totalBytesWritten)/Double(totalBytesExpectedToWrite)
        assetDownloadItem.downloadPercentageComplete = percentageComplete
        
        generateReport()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let (index, assetDownloadItem) = downloadingAssetDownloadItem(withURLSessionTask: downloadTask) else {
            return
        }
        
        downloading.remove(at: index)
        resumePausedDownloads()
        
        do {
            let data = try Data(contentsOf: location)
            
            assetDownloadItem.completionHandler?(.success(data))
        } catch {
            assetDownloadItem.completionHandler?(.failure(APIError.invalidData))
        }
        
        generateReport()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let (index, assetDownloadItem) = downloadingAssetDownloadItem(withURLSessionTask: task)  else {
            return
        }
        
        downloading.remove(at: index)
        resumePausedDownloads()
        
        guard let error = error else {
            assetDownloadItem.completionHandler?(.failure(APIError.unknown))
            return
        }
        
        assetDownloadItem.completionHandler?(.failure(error))
        
        generateReport()
    }
}

extension AssetDownloadManager {
    
    // MARK: - Report
    
    private func generateReport() {
        guard shouldGenerateReport else {
            return
        }
        
        print("-------------------------------")
        print("-       Download Report       -")
        print("-------------------------------")
        print("Date: \(Date())")
        print("Operating in downloading mode: \(downloadingMode)")
        print("Number of items downloading: \(downloading.count)")
        print("Number of items waiting for download: \(waiting.count)")
        print("Number of items canceled for download: \(cancelled.count)")
        
        print("")
        print("Items:")
        
        let combined = downloading + waiting + cancelled
        
        if combined.count > 0 {
            for assetDownloadItem in combined {
                let percentage = (assetDownloadItem.downloadPercentageComplete*10000).rounded()/100
                print("\(assetDownloadItem.url.absoluteString) (\(percentage)%) \(assetDownloadItem.status) \(assetDownloadItem.forceDownload ? "forced" : "unforced")")
            }
        } else {
            print("Empty")
        }
        
        print("")
    }
}

//
//  AssetDownloadsSession.swift
//  UnequalDownloads-Example
//
//  Created by William Boles on 14/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import UIKit
import os

typealias AssetDownloadCompletionHandler = ((_ result: Result<Data, Error>) -> Void)

enum DownloadingMode: CustomStringConvertible {
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

class AssetDownloadsSession {

    private var downloading = [AssetDownloadItemType]()
    private var waiting = [AssetDownloadItemType]()
    private var cancelled = [AssetDownloadItemType]()
    
    private let accessQueue = DispatchQueue(label: "com.williamboles.downloadssession")
    
    private let notificationCenter: NotificationCenterType
    private let assetDownloadItemFactory: AssetDownloadItemFactoryType
    private let session: URLSessionType
    
    private var downloadingMode: DownloadingMode {
        if (downloading.first?.immediateDownload ?? false) || (waiting.last?.immediateDownload ?? false) {
            return .single
        }
        
        return .multiple
    }
    
    // MARK: - Singleton
    
    static let shared = AssetDownloadsSession()
    
    // MARK: - Init
    
    init(urlSessionFactory: URLSessionFactoryType = URLSessionFactory(), assetDownloadItemFactory: AssetDownloadItemFactoryType = AssetDownloadItemFactory(), notificationCenter: NotificationCenterType = NotificationCenter.default) {
        self.assetDownloadItemFactory = assetDownloadItemFactory
        self.notificationCenter = notificationCenter
        self.session = urlSessionFactory.defaultSession()
            
        registerForNotifications()
    }
    
    // MARK: - Notification
    
    private func registerForNotifications() {
        notificationCenter.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { _ in
            self.hardCancellSoftCancelledDownloads()
        }
    }
    
    private func hardCancellSoftCancelledDownloads() {
        accessQueue.sync {
            os_log(.info, "Hard cancelling %{public}d items", cancelled.count)
            
            for downloadAssetItem in cancelled {
                downloadAssetItem.cancel()
            }
            
            cancelled.removeAll()
        }
    }
    
    // MARK: - Addition
    
    func scheduleDownload(url: URL, immediateDownload: Bool, completionHandler: @escaping ((_ result: Result<Data, Error>) -> ())) {
        accessQueue.sync {
            if immediateDownload {
                pauseAllDownloads()
            }
            
            let assetDownloadItem = assetDownloadItemFactory.assetDownloadItem(forURL: url, session: session, immediateDownload: immediateDownload) { (assetDownloadItem, result) in
                self.accessQueue.sync {
                    self.finishedDownload(ofAssetDownloadItem: assetDownloadItem)
                    self.startDownloads()
                }

                completionHandler(result)
            }
            
            if let (_, existingAssetDownloadItem) = downloadingAssetDownloadItem(withURL: assetDownloadItem.url) {
                os_log(.info, "Found existing active download so coalescing them for: %{public}@", assetDownloadItem.description)
                existingAssetDownloadItem.coalesce(assetDownloadItem)
            } else if let (_, existingAssetDownloadItem) = waitingAssetDownloadItem(withURL: assetDownloadItem.url) {
                os_log(.info, "Found existing waiting download so coalescing them for: %{public}@", assetDownloadItem.description)
                existingAssetDownloadItem.coalesce(assetDownloadItem)
                // Move download item to the front of the waiting stack
                moveAssetDownloadItemToFrontOfWaiting(assetDownloadItem)
            } else if let (_, existingAssetDownloadItem) = cancelledAssetDownloadItem(withURL: assetDownloadItem.url) {
                os_log(.info, "Found existing soft-cancelled download so reviving download for: %{public}@", assetDownloadItem.description)
                //as the download was cancelled no need to coalesce - just override
                existingAssetDownloadItem.completionHandler = assetDownloadItem.completionHandler
                existingAssetDownloadItem.immediateDownload = assetDownloadItem.immediateDownload
                
                // Add to front of waiting stack
                transferFromCancelledToWaiting(assetDownloadItem: existingAssetDownloadItem)
            } else {
                os_log(.info, "Adding new download: %{public}@", assetDownloadItem.description)
                // Add to front of waiting stack
                waiting.append(assetDownloadItem)
            }
            
            startDownloads()
        }
    }
    
    // MARK: - Cancel
    
    func cancelDownload(url: URL) {
        accessQueue.sync {
            var assetDownloadItemToBeSuspended: AssetDownloadItemType?
            
            if let (index, assetDownloadItem) = downloadingAssetDownloadItem(withURL: url) {
                assetDownloadItemToBeSuspended = assetDownloadItem
                downloading.remove(at: index)
            } else if let (index, assetDownloadItem) = waitingAssetDownloadItem(withURL: url) {
                assetDownloadItemToBeSuspended = assetDownloadItem
                waiting.remove(at: index)
            }
            
            if let assetDownloadItem = assetDownloadItemToBeSuspended {
                assetDownloadItem.pause()
                cancelled.append(assetDownloadItem)
                
                os_log(.info, "Cancelled download: %{public}@", assetDownloadItem.description)
            }
            
            //Start next downloads
            startDownloads()
        }
    }
    
    // MARK: - Pause
    
    private func pauseAllDownloads() {
        guard downloading.count > 0 else {
            return
        }
        
        os_log(.info, "Pausing %{public}d active downloads", downloading.count)
        
        for assetDownloadItem in downloading.reversed() {
            assetDownloadItem.pause()
            transferFromDownloadingToWaiting(assetDownloadItem: assetDownloadItem)
        }
    }
    
    // MARK: - Resume
    
    private func startDownloads() {
        guard waiting.count > 0 else {
            return
        }
        
        switch downloadingMode {
        case .multiple:
            let assetDownloadItems = waiting.reversed() as [AssetDownloadItemType]
            if assetDownloadItems.count > 0 {
                startDownloading(assetDownloadItems: assetDownloadItems)
                waiting.removeAll()
            }
        case .single:
            if let assetDownloadItem = waiting.last {
                if assetDownloadItem.immediateDownload {
                    startDownloading(assetDownloadItems: [assetDownloadItem])
                    waiting.removeLast()
                }
            }
        }
    }
    
    private func startDownloading(assetDownloadItems: [AssetDownloadItemType]) {
        os_log(.info, "Operating in %{public}@ mode", downloadingMode.description)
        
        for assetDownloadItem in assetDownloadItems {
            downloading.append(assetDownloadItem)
            assetDownloadItem.resume()
            
            os_log(.info, "Started downloading of: %{public}@", assetDownloadItem.description)
        }
        
        os_log(.info, "Currently downloading %{public}d assets", downloading.count)
    }
    
    // MARK: - Finish
    
    private func finishedDownload(ofAssetDownloadItem assetDownloadItem: AssetDownloadItemType) {
        guard let index = downloading.firstIndex(where: { $0.url == assetDownloadItem.url })  else {
            return
        }
        
        assetDownloadItem.done()
        downloading.remove(at: index)
        
        os_log(.info, "Finished download of: %{public}@", assetDownloadItem.description)
        os_log(.info, "Currently downloading %{public}d assets", downloading.count)
    }
    
    // MARK: - Transfer
    
    private func transferFromDownloadingToWaiting(assetDownloadItem: AssetDownloadItemType) {
        guard let index = downloading.firstIndex(where: { $0.url == assetDownloadItem.url }) else {
            return
        }
        
        downloading.remove(at: index)
        waiting.append(assetDownloadItem)
    }
    
    private func transferFromCancelledToWaiting(assetDownloadItem: AssetDownloadItemType) {
        guard let index = cancelled.firstIndex(where: { $0.url == assetDownloadItem.url }) else {
            return
        }
        
        cancelled.remove(at: index)
        waiting.append(assetDownloadItem)
    }
    
    private func moveAssetDownloadItemToFrontOfWaiting(_ assetDownloadItem: AssetDownloadItemType) {
        guard let index = waiting.firstIndex(where: { $0.url == assetDownloadItem.url }) else {
            return
        }
        
        waiting.remove(at: index)
        waiting.append(assetDownloadItem)
    }
    
    // MARK: - Search
    
    private func assetDownloadItem(withURL url: URL, in assetDownloadItems: [AssetDownloadItemType]) -> (Int, AssetDownloadItemType)? {
        for (index, assetDownloadItem) in assetDownloadItems.enumerated() {
            if assetDownloadItem.url == url {
                return (index, assetDownloadItem)
            }
        }
        
        return nil
    }
    
    private func waitingAssetDownloadItem(withURL url: URL) -> (Int, AssetDownloadItemType)? {
        return assetDownloadItem(withURL: url, in: waiting)
    }
    
    private func downloadingAssetDownloadItem(withURL url: URL) -> (Int, AssetDownloadItemType)? {
        return assetDownloadItem(withURL: url, in: downloading)
    }
    
    private func cancelledAssetDownloadItem(withURL url: URL) -> (Int, AssetDownloadItemType)? {
        return assetDownloadItem(withURL: url, in: cancelled)
    }
}

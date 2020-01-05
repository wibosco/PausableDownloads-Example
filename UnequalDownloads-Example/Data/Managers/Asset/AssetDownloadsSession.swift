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

class AssetDownloadsSession: AssetDownloadItemDelegate {

    private var immediateAssetDownloadItem: AssetDownloadItemType?
    private var assetDownloadItems = [AssetDownloadItemType]()
    
    private let accessQueue = DispatchQueue(label: "com.williamboles.downloadssession")
    
    private let notificationCenter: NotificationCenterType
    private let assetDownloadItemFactory: AssetDownloadItemFactoryType
    private let session: URLSessionType
    
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
            self.accessQueue.sync {
                os_log(.info, "Cancelling hibernating items")
                
                self.assetDownloadItems = self.assetDownloadItems.filter { (assetDownloadItem) -> Bool in
                    let hibernating = assetDownloadItem.state == .hibernating
                    if hibernating {
                        assetDownloadItem.cancel()
                    }
                    
                    return !hibernating
                }
            }
        }
    }
    
    // MARK: - Schedule
    
    func scheduleDownload(url: URL, immediateDownload: Bool, completionHandler: @escaping ((_ result: Result<Data, Error>) -> ())) {
        accessQueue.sync {
            let potentialImmediateAssetDownloadItem: AssetDownloadItemType
            
            if var existingAssetDownloadItem = coalescableAssetDownloadItem(withURL: url) {
                switch existingAssetDownloadItem.state {
                case .downloading, .paused:
                    os_log(.info, "Found existing %{public}@ download so coalescing them for: %{public}@", existingAssetDownloadItem.state.rawValue, existingAssetDownloadItem.description)
                   existingAssetDownloadItem.coalesceDownloadCompletionHandler(completionHandler)
                case .hibernating:
                   os_log(.info, "Found existing hibernating download so reviving download for: %{public}@", existingAssetDownloadItem.description)
                   //as the download is in hibernation no need to coalesce - just override
                   existingAssetDownloadItem.downloadCompletionHandler = completionHandler
                   existingAssetDownloadItem.awaken()
                default:
                    assertionFailure("Unexpected state for an existing download")
                }
                
                potentialImmediateAssetDownloadItem = existingAssetDownloadItem
            } else {
                let assetDownloadItem = assetDownloadItemFactory.assetDownloadItem(forURL: url, session: session, delegate: self, downloadCompletionHandler: completionHandler)
                assetDownloadItems.append(assetDownloadItem)
                os_log(.info, "Adding new download: %{public}@", assetDownloadItem.description)
                
                potentialImmediateAssetDownloadItem = assetDownloadItem
            }
            
            if immediateDownload {
                pauseAllDownloads()
                immediateAssetDownloadItem = potentialImmediateAssetDownloadItem
            }
            
            startDownloads()
        }
    }
    
    // MARK: - Download
    
    private func startDownloads() {
        if let immediateAssetDownloadItem = immediateAssetDownloadItem {
            os_log(.info, "Operating in single download mode")
            if immediateAssetDownloadItem.isResumable {
                immediateAssetDownloadItem.resume()
            }
        } else {
            let pausedAssetDownloadItems = self.pausedAssetDownloadItems()
            if pausedAssetDownloadItems.count > 0 {
                os_log(.info, "Operating in multiple download mode")
                for assetDownloadItem in pausedAssetDownloadItems {
                    os_log(.info, "Started downloading of: %{public}@", assetDownloadItem.description)
                    assetDownloadItem.resume()
                }
            }
        }
        
        let downloadingAssetDownloadItems = self.downloadingAssetDownloadItems()
        os_log(.info, "Currently downloading %{public}d assets", downloadingAssetDownloadItems.count)
    }
    
    // MARK: - Cancel
    
    func cancelDownload(url: URL) {
        accessQueue.sync {
            let assetDownloadItem = assetDownloadItems.first { $0.url == url }
            guard let assetDownloadItemToBeSuspended = assetDownloadItem else {
                return
            }
            
            os_log(.info, "Download: %{public}@ going into hibernation", assetDownloadItemToBeSuspended.description)
            assetDownloadItemToBeSuspended.hibernate()
            
            if immediateAssetDownloadItem?.url == assetDownloadItemToBeSuspended.url {
                immediateAssetDownloadItem = nil
            }
            
            //Start next downloads
            startDownloads()
        }
    }
    
    // MARK: - Pause
    
    private func pauseAllDownloads() {
        let downloadingAssetDownloadItems = self.downloadingAssetDownloadItems()
        guard downloadingAssetDownloadItems.count > 0 else {
            return
        }
        
        os_log(.info, "Pausing %{public}d active downloads", downloadingAssetDownloadItems.count)
        
        for assetDownloadItem in downloadingAssetDownloadItems {
            assetDownloadItem.pause()
        }
        
        immediateAssetDownloadItem = nil
    }
    
    // MARK: - Finished
    
    private func finishedDownload(ofAssetDownloadItem assetDownloadItem: AssetDownloadItemType) {
        os_log(.info, "Finished download of: %{public}@", assetDownloadItem.description)
        
        if immediateAssetDownloadItem?.url == assetDownloadItem.url {
            immediateAssetDownloadItem = nil
        }
        
        if let index = assetDownloadItems.firstIndex(where: { $0.url == assetDownloadItem.url }) {
            assetDownloadItems.remove(at: index)
        }
    }
    
    // MARK: - Query
    
    private func pausedAssetDownloadItems() -> [AssetDownloadItemType] {
        return assetDownloadItems.filter { $0.state == .paused }
    }
    
    private func downloadingAssetDownloadItems() -> [AssetDownloadItemType] {
        return assetDownloadItems.filter { $0.state == .downloading }
    }
    
    // MARK: - Search
    
    private func coalescableAssetDownloadItem(withURL url: URL) -> AssetDownloadItemType? {
        return assetDownloadItems.first { $0.url == url && $0.isCoalescable }
    }
    
    // MARK: - AssetDownloadItemDelegate
    
    func assetDownloadItemDone(_ assetDownloadItem: AssetDownloadItemType) {
        accessQueue.sync {
           self.finishedDownload(ofAssetDownloadItem: assetDownloadItem)
           self.startDownloads()
        }
    }
}

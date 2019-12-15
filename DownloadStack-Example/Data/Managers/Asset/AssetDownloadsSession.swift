//
//  AssetDownloadsSession.swift
//  DownloadStack-Example
//
//  Created by William Boles on 14/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import UIKit

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
    
    private let notificationCenter: NotificationCenterType
    
    var downloadingMode: DownloadingMode {
        if (downloading.first?.immediateDownload ?? false) || (waiting.last?.immediateDownload ?? false) {
            return .single
        }
        
        return .multiple
    }
    
    // MARK: - Init
    
    init(notificationCenter: NotificationCenterType = NotificationCenter.default) {
        self.notificationCenter = notificationCenter
            
        registerForNotifications()
    }
    
    // MARK: - Notification
    
    private func registerForNotifications() {
        notificationCenter.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main) { _ in
            self.hardCancellSoftCancelledDownloads()
        }
    }
    
    private func hardCancellSoftCancelledDownloads() {
        print("Hard cancelling \(cancelled.count) items")
        
        for downloadAssetItem in cancelled {
            downloadAssetItem.hardCancel()
        }
        
        cancelled.removeAll()
    }
    
    // MARK: - Addition
    
    func insert(assetDownloadItem: AssetDownloadItemType) {
        if let (_, existingAssetDownloadItem) = downloadingAssetDownloadItem(withURL: assetDownloadItem.url) {
            print("Found existing active download so coalescing them")
            existingAssetDownloadItem.coalesce(assetDownloadItem)
        } else if let (_, existingAssetDownloadItem) = waitingAssetDownloadItem(withURL: assetDownloadItem.url) {
            print("Found existing waitingg download so coalescing them")
            existingAssetDownloadItem.coalesce(assetDownloadItem)
            // Move download item to the front of the waiting stack
            moveAssetDownloadItemToFrontOfWaiting(assetDownloadItem)
        } else if let (_, existingAssetDownloadItem) = cancelledAssetDownloadItem(withURL: assetDownloadItem.url) {
            print("Found existing soft-cancelled download so reviving download")
            //as the download was cancelled no need to coalesce - just override
            existingAssetDownloadItem.completionHandler = assetDownloadItem.completionHandler
            existingAssetDownloadItem.immediateDownload = assetDownloadItem.immediateDownload
            
            // Add to front of waiting stack
            transferFromCancelledToWaiting(assetDownloadItem: existingAssetDownloadItem)
        } else {
            print("New download")
            // Add to front of waiting stack
            waiting.append(assetDownloadItem)
        }
    }
    
    // MARK: - Cancel
    
    func cancelDownload(url: URL) {
        var assetDownloadItemToBeSuspended: AssetDownloadItemType?
        
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
            
            print("Cancelled download: \(assetDownloadItem)")
        }
        
        
        generateReport()
    }
    
    // MARK: - Pause
    
    func pauseAllDownloads() {
        guard downloading.count > 0 else {
            return
        }
        
        print("Pausing all downloads")
        
        for assetDownloadItem in downloading.reversed() {
            assetDownloadItem.pause()
            transferFromDownloadingToWaiting(assetDownloadItem: assetDownloadItem)
        }
        
        print("Currently paused the download of \(waiting.count) assets")
        
        generateReport()
    }
    
    // MARK: - Resume
    
    func startDownloads() {
        guard waiting.count > 0 else {
            print("Downloading \(downloading.count) assets")
            return
        }
        
        print("Starting downloads in \(downloadingMode) mode with \(waiting.count) assets to download")
        
        switch downloadingMode {
        case .multiple:
            let assetDownloadItems = waiting.reversed() as [AssetDownloadItemType]
            startDownloading(assetDownloadItems: assetDownloadItems)
            waiting.removeAll()
        case .single:
            if let assetDownloadItem = waiting.last {
                startDownloading(assetDownloadItems: [assetDownloadItem])
                waiting.removeLast()
            }
        }
        
        print("Currently downloading \(downloading.count) assets")
        
        generateReport()
    }
    
    private func startDownloading(assetDownloadItems: [AssetDownloadItemType]) {
        for assetDownloadItem in assetDownloadItems {
            downloading.append(assetDownloadItem)
            assetDownloadItem.resume()
            
            print("Started downloading: \(assetDownloadItem)")
        }
    }
    
    // MARK: - Finish
    
    func finishedDownload(ofAssetDownloadItem assetDownloadItem: AssetDownloadItemType) {
        guard let index = downloading.firstIndex(where: { $0.url == assetDownloadItem.url })  else {
            return
        }
        
        assetDownloadItem.done()
        downloading.remove(at: index)
        
        print("Finish downloading: \(assetDownloadItem)")
        
        generateReport()
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
    
    func assetDownloadItem(withURLSessionTask sessionTask: URLSessionTask) -> AssetDownloadItemType? {
        guard let url = sessionTask.currentRequest?.url else {
            return nil
        }
        
        let combined = downloading + waiting + cancelled
        if let (_, foundAssetDownloadItem) = assetDownloadItem(withURL: url, in: combined) {
            return foundAssetDownloadItem
        }
        
        return nil
    }
    
    // MARK: - Report
    
    private func generateReport() {
//        print("-------------------------------")
//        print("-       Download Report       -")
//        print("-------------------------------")
//        print("Date: \(Date())")
//        print("Operating in downloading mode: \(downloadingMode)")
//        print("Number of items downloading: \(downloading.count)")
//        print("Number of items waiting for download: \(waiting.count)")
//        print("Number of items canceled for download: \(cancelled.count)")
//
//        print("")
//        print("Items:")
//
//        let combined = downloading + waiting + cancelled
//
//        if combined.count > 0 {
//            for assetDownloadItem in combined {
//                let percentage = (assetDownloadItem.downloadPercentageComplete*10000).rounded()/100
//                print("\(assetDownloadItem.url.absoluteString) (\(percentage)%) \(assetDownloadItem.status) \(assetDownloadItem.immediateDownload ? "forced" : "unforced")")
//            }
//        } else {
//            print("Empty")
//        }
//
//        print("")
    }
}

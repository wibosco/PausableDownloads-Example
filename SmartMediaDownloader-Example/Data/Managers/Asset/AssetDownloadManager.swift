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
    
    private var waitingStack = Stack<AssetDownloadItem>()
    private var currentlyDownloadingItems = [AssetDownloadItem]()
    
    private static let maximumConcurrentDownloadsResetValue = 4
    
    private var maximumConcurrentDownloads = AssetDownloadManager.maximumConcurrentDownloadsResetValue
        
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
        
        waitingStack.push(assetDownloadItem)
        
        resumeDownloads()
    }
    
    func scheduleDownload(url: URL, force: Bool, completionHandler: @escaping AssetDownloadItemCompletionHandler) {
        download(url: url, force: force, completionHandler: completionHandler)
    }
    
    private func pauseDownloads() {
        for assetDownloadItem in currentlyDownloadingItems.reversed() {
            assetDownloadItem.pause()
            waitingStack.push(assetDownloadItem)
        }
        
        currentlyDownloadingItems.removeAll()
    }
    
    private func resumeDownloads() {
        updatedConcurrentDownloadLimitIfNeeded()
        
        for _ in currentlyDownloadingItems.count..<maximumConcurrentDownloads {
            guard let assetDownloadItem = waitingStack.pop() else {
                return
            }
            
            currentlyDownloadingItems.append(assetDownloadItem)
            assetDownloadItem.resume()
        }
        
        generateReport()
    }
    
    private func updatedConcurrentDownloadLimitIfNeeded() {
        guard currentlyDownloadingItems.first?.forcedDownload == false else {
            maximumConcurrentDownloads = 1
            return
        }
        
        guard let assetDownloadItem = waitingStack.peek else {
            maximumConcurrentDownloads = AssetDownloadManager.maximumConcurrentDownloadsResetValue
            return
        }
        
        if assetDownloadItem.forcedDownload {
            maximumConcurrentDownloads = 1
        } else {
            maximumConcurrentDownloads = AssetDownloadManager.maximumConcurrentDownloadsResetValue
        }
    }
    
    func cancelDownload(url: URL) {
        var assetDownloadItemToBeCancelled: AssetDownloadItem?
        
        for (index, assetDownloadItem) in currentlyDownloadingItems.enumerated() {
            if assetDownloadItem.url == url {
                assetDownloadItemToBeCancelled = assetDownloadItem
                currentlyDownloadingItems.remove(at: index)
                break
            }
        }
        
        if assetDownloadItemToBeCancelled == nil {
            for assetDownloadItem in waitingStack {
                if assetDownloadItem.url == url {
                    assetDownloadItemToBeCancelled = assetDownloadItem
                    waitingStack.remove(assetDownloadItem)
                    break
                }
            }
        }
        
        assetDownloadItemToBeCancelled?.cancel()
        resumeDownloads()
    }
    
    // MARK: - Executing
    
    fileprivate func executingAssetDownloadItem(for downloadTask: URLSessionTask) -> AssetDownloadItem? {
        for assetDownloadItem in currentlyDownloadingItems {
            if assetDownloadItem.url == downloadTask.currentRequest?.url {
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
        
        guard let executingAssetDownloadItem = executingAssetDownloadItem(for: downloadTask), let index = self.currentlyDownloadingItems.index(of: executingAssetDownloadItem)  else {
            return
        }
        
        self.currentlyDownloadingItems.remove(at: index)
        self.resumeDownloads()
        
        do {
            let data = try Data(contentsOf: location)
            
            executingAssetDownloadItem.completionHandler?(.success(data))
        } catch {
            executingAssetDownloadItem.completionHandler?(.failure(APIError.invalidData))
        }
        
        generateReport()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let executingAssetDownloadItem = executingAssetDownloadItem(for: downloadTask)  else {
            return
        }
        
        let percentageComplete = Double(totalBytesWritten)/Double(totalBytesExpectedToWrite)
        executingAssetDownloadItem.downloadedPercentage = percentageComplete
        
        generateReport()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let executingAssetDownloadItem = executingAssetDownloadItem(for: task), let index = self.currentlyDownloadingItems.index(of: executingAssetDownloadItem)  else {
            return
        }
        
        self.currentlyDownloadingItems.remove(at: index)
        self.resumeDownloads()
        
        guard let error = error else {
            executingAssetDownloadItem.completionHandler?(.failure(APIError.unknown))
            return
        }
        
        executingAssetDownloadItem.completionHandler?(.failure(error))
        
        generateReport()
    }
}

extension AssetDownloadManager {
    
    // MARK: - Report
    
    private func generateReport() {
        print("-------------------------------")
        print("-       Download Report       -")
        print("-------------------------------")
        print("Date: \(Date())")
        print("Number of possible concurrent downloads: \(maximumConcurrentDownloads)")
        print("Number of items downloading: \(currentlyDownloadingItems.count)")
        print("Number of items waitng for download: \(waitingStack.count)")
        
        print("")
        print("Downloading Items:")
        
        if currentlyDownloadingItems.count > 0 {
            for assetDownloadItem in currentlyDownloadingItems {
                let percentage = (assetDownloadItem.downloadedPercentage*10000).rounded()/100
                print("\(assetDownloadItem.url.absoluteString) (\(percentage)%)  \(assetDownloadItem.forcedDownload ? "forced download" : "unforced download")")
            }
        } else {
            print("Empty")
        }
        
        print("")
        print("Waiting Items: ")
        
        if waitingStack.count > 0 {
            for assetDownloadItem in waitingStack {
                let percentage = (assetDownloadItem.downloadedPercentage*10000).rounded()/100
                print("\(assetDownloadItem.url.absoluteString) (\(percentage)%)")
            }
        } else {
            print("Empty")
        }
        
        print("")
    }
}

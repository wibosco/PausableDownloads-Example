//
//  Downloader.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 14/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation
import os

//called on whichever thread `URLSession` delivers on - callers hop to their own queue
typealias DownloadCompletionHandler = (Result<Data, Error>) -> ()

//identifies one caller's interest in a URL rather than one download, so several callers
//can coalesce onto a single download of that URL and each pause and be answered
//independently. The URL comes back with the token so a pause can go straight to the
//download it belongs to
struct DownloadToken: Hashable {
    let url: URL
    
    private let id = UUID()
    
    init(url: URL) {
        self.url = url
    }
}

protocol Downloader {
    @discardableResult
    func download(_ url: URL,
                  completionHandler: @escaping DownloadCompletionHandler) -> DownloadToken
    func pause(_ token: DownloadToken)
}

final class DefaultDownloader: NSObject, Downloader {
    private final class Download {
        let url: URL
        
        private(set) var completionHandlers = [DownloadToken: DownloadCompletionHandler]()
        private(set) var stage: DownloadStage = .ready
        private(set) var task: URLSessionDownloadTaskType?
        private(set) var resumptionData: Data?
        
        // MARK: - Init
        
        init(url: URL) {
            self.url = url
        }
        
        // MARK: - Callers
        
        //a token is unique per caller, so this adds to whoever is already waiting rather
        //than replacing them
        func add(_ completionHandler: @escaping DownloadCompletionHandler,
                 for token: DownloadToken) {
            completionHandlers[token] = completionHandler
        }
        
        //`true` when the token was one of ours
        @discardableResult
        func remove(_ token: DownloadToken) -> Bool {
            completionHandlers.removeValue(forKey: token) != nil
        }
        
        var hasCallers: Bool {
            !completionHandlers.isEmpty
        }
        
        // MARK: - Stage
        
        //a download only needs a task when nothing is already on its way - freshly
        //constructed, or paused with resumption data waiting to be picked up
        var needsTask: Bool {
            stage == .ready || stage == .paused
        }
        
        func markRunning(with task: URLSessionDownloadTaskType) {
            stage = .running
            self.task = task
            resumptionData = nil
        }
        
        //returns the task to cancel, or nil if there isn't one running
        func markPausing() -> URLSessionDownloadTaskType? {
            guard stage == .running,
                  let task = task else {
                return nil
            }
            
            stage = .pausing
            
            return task
        }
        
        func markPaused(with resumptionData: Data) {
            stage = .paused
            self.resumptionData = resumptionData
            task = nil
        }
        
        //a result only counts if it came from the task this download is currently running -
        //not one it has since replaced, and not one that is winding down after a pause
        func isAwaiting(taskIdentifier: Int) -> Bool {
            stage == .running && task?.taskIdentifier == taskIdentifier
        }
    }
    
    private enum DownloadStage: Equatable {
        case ready                            //constructed, no task yet - lives for one `sync` block
        case running
        case pausing                          //cancel issued, resumption data hasn't landed yet
        case paused
    }
    
    //one entry per URL - everybody who wants it coalesces onto the same download
    private var downloads = [URL: Download]()
    private let queue = DispatchQueue(label: "com.williamboles.downloader")
    
    private let urlSessionFactory: URLSessionFactoryType
    private lazy var session: URLSessionType = urlSessionFactory.defaultSession(delegate: self)
    private let memoryPressureMonitor: MemoryPressureMonitor
    
    // MARK: - Singleton
    
    static let shared = DefaultDownloader()
    
    // MARK: - Init
    
    init(urlSessionFactory: URLSessionFactoryType = URLSessionFactory(),
         memoryPressureMonitor: MemoryPressureMonitor = DefaultMemoryPressureMonitor()) {
        self.urlSessionFactory = urlSessionFactory
        self.memoryPressureMonitor = memoryPressureMonitor
        
        super.init()
        
        memoryPressureMonitor.startMonitoring { [weak self] in
            self?.purgePausedDownloads()
        }
    }
    
    // MARK: - ThreadSafety
    
    //`downloads` is only ever reached from inside here, so a read-modify-write of it
    //stays indivisible
    private func sync<T>(_ body: () -> T) -> T {
        //`sync` isn't reentrant - trap on a nested call rather than deadlock
        dispatchPrecondition(condition: .notOnQueue(queue))
        
        return queue.sync(execute: body)
    }
    
    // MARK: - MemoryPressure
    
    private func purgePausedDownloads() {
        sync {
            os_log(.info, "Purging paused items under memory pressure")
            
            downloads = downloads.filter { $0.value.stage != .paused }
        }
    }
    
    // MARK: - Download
    
    @discardableResult
    func download(_ url: URL,
                  completionHandler: @escaping DownloadCompletionHandler) -> DownloadToken {
        let token = DownloadToken(url: url)
        
        sync {
            let download = downloads[url] ?? makeDownload(for: url)
            download.add(completionHandler, for: token)
            
            if download.needsTask {
                startDownload(download)
            } else {
                os_log(.info, "Coalescing onto an existing active download of: %{public}@", url.absoluteString)
            }
        }
        
        return token
    }
    
    private func makeDownload(for url: URL) -> Download {
        dispatchPrecondition(condition: .onQueue(queue))
        
        let download = Download(url: url)
        downloads[url] = download
        
        return download
    }
    
    private func startDownload(_ download: Download) {
        dispatchPrecondition(condition: .onQueue(queue))
        
        let task: URLSessionDownloadTaskType
        if let resumptionData = download.resumptionData {
            os_log(.info, "Resuming a paused download: %{public}@", download.url.absoluteString)
            task = session.downloadTask(withResumeData: resumptionData)
        } else {
            os_log(.info, "Starting a new download: %{public}@", download.url.absoluteString)
            task = session.downloadTask(with: download.url)
        }
        
        download.markRunning(with: task)
        
        task.resume()
    }
    
    // MARK: - Pause
    
    func pause(_ token: DownloadToken) {
        let url = token.url
        
        let taskToPause: URLSessionDownloadTaskType? = sync {
            guard let download = downloads[url],
                  download.remove(token) else {
                return nil
            }
            
            guard !download.hasCallers else {
                os_log(.info, "Dropping a coalesced caller from a download others still want: %{public}@", url.absoluteString)
                return nil
            }
            
            guard let task = download.markPausing() else {
                return nil
            }
            
            os_log(.info, "Pausing download: %{public}@", url.absoluteString)
            
            return task
        }
        
        guard let taskToPause = taskToPause else {
            return
        }
        
        taskToPause.cancel(byProducingResumeData: { [weak self] data in
            self?.finishPausing(for: url,
                                resumptionData: data)
        })
    }
    
    private func finishPausing(for url: URL,
                               resumptionData: Data?) {
        sync {
            guard let download = downloads[url],
                  download.stage == .pausing else {
                os_log(.info, "Ignoring resumption data for a download that is no longer pausing: %{public}@", url.absoluteString)
                return
            }
            
            if let resumptionData = resumptionData {
                os_log(.info, "Cancelled download task has produced %{public}d bytes of resumption data for %{public}@", resumptionData.count, url.absoluteString)
                
                download.markPaused(with: resumptionData)
            }
            
            if download.hasCallers {
                //whilst this download was being paused another request came in for it, so
                //pick it straight back up - from the resumption data if there was any
                os_log(.info, "Restarting download: %{public}@", url.absoluteString)
                
                startDownload(download)
            } else if resumptionData == nil {
                os_log(.error, "Dropping a paused download that produced no resumption data: %{public}@", url.absoluteString)
                
                downloads[url] = nil
            }
        }
    }
    
    // MARK: - DelegateHandling
    
    func handleProgress(for url: URL,
                        totalBytesWritten: Int64,
                        expectedTotalBytes: Int64) {
        let downloadedPercentage = (Double(totalBytesWritten)/Double(expectedTotalBytes)) * 100
        os_log(.info, "Downloaded %{public}.02f%% of %{public}@", downloadedPercentage, url.absoluteString)
    }
    
    func handleResumption(for url: URL,
                          fileOffset: Int64,
                          expectedTotalBytes: Int64) {
        let resumptionPercentage = (Double(fileOffset)/Double(expectedTotalBytes)) * 100
        os_log(.info, "Resuming download: %{public}@ from: %{public}.02f%%", url.absoluteString, resumptionPercentage)
    }
    
    func handleFinishedDownloading(for url: URL,
                                   taskIdentifier: Int,
                                   to location: URL) {
        //`location` is only valid until this delegate call returns, so read it now
        let result: Result<Data, Error>
        do {
            result = .success(try Data(contentsOf: location))
            
            os_log(.info, "Download completed for: %{public}@", url.absoluteString)
        } catch let error {
            result = .failure(NetworkingError.invalidData(underlyingError: error))
            
            os_log(.error, "Download completed for: %{public}@ but its file could not be read: %{public}@", url.absoluteString, error.localizedDescription)
        }
        
        deliverResult(result,
                      for: url,
                      taskIdentifier: taskIdentifier)
    }
    
    func handleFailedDownloading(for url: URL,
                                 taskIdentifier: Int,
                                 error: Error) {
        //a pause or a purge cancels the task; that isn't a failure anybody asked about
        if let error = error as? URLError, error.code == .cancelled {
            os_log(.info, "Ignoring the cancellation of task: %{public}d", taskIdentifier)
            return
        }
        
        os_log(.error, "Download failed for: %{public}@ with error: %{public}@", url.absoluteString, error.localizedDescription)
        
        deliverResult(.failure(NetworkingError.retrieval(underlyingError: error)),
                      for: url,
                      taskIdentifier: taskIdentifier)
    }
    
    //the result is made once and handed to everybody who coalesced onto this download
    private func deliverResult(_ result: Result<Data, Error>,
                               for url: URL,
                               taskIdentifier: Int) {
        let completionHandlers: [DownloadCompletionHandler] = sync {
            guard let download = downloads[url],
                  download.isAwaiting(taskIdentifier: taskIdentifier) else {
                os_log(.info, "Ignoring a result for a task this downloader isn't waiting on: %{public}d", taskIdentifier)
                return []
            }
            
            downloads[url] = nil
            
            return Array(download.completionHandlers.values)
        }
        
        //can't happen within `sync` in case the callee blocks the thread
        completionHandlers.forEach { $0(result) }
    }
}

private extension URLSessionTask {
    var downloadURL: URL? {
        originalRequest?.url
    }
}

extension DefaultDownloader: URLSessionDownloadDelegate {
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let url = downloadTask.downloadURL else {
            return
        }
        
        handleProgress(for: url,
                       totalBytesWritten: totalBytesWritten,
                       expectedTotalBytes: totalBytesExpectedToWrite)
    }
    
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didResumeAtOffset fileOffset: Int64,
                    expectedTotalBytes: Int64) {
        guard let url = downloadTask.downloadURL else {
            return
        }
        
        handleResumption(for: url,
                         fileOffset: fileOffset,
                         expectedTotalBytes: expectedTotalBytes)
    }
    
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let url = downloadTask.downloadURL else {
            return
        }
        
        handleFinishedDownloading(for: url,
                                  taskIdentifier: downloadTask.taskIdentifier,
                                  to: location)
    }
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        //a success has already been dealt with by `didFinishDownloadingTo`
        guard let error = error,
              let url = task.downloadURL else {
            return
        }
        
        handleFailedDownloading(for: url,
                                taskIdentifier: task.taskIdentifier,
                                error: error)
    }
}

//
//  AssetDownloadsSession.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 14/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation
import os

typealias DownloadCompletionHandler = ((_ result: Result<Data, Error>) -> ())

/* Identifies one caller's interest in a URL rather than one download, so several callers
 can share a single download of that URL and each pause and be answered independently. The
 URL comes back with the token so a pause can go straight to the download it belongs to.
 */
struct DownloadToken: Hashable {
    let url: URL
    
    private let rawValue = UUID()
    
    init(url: URL) {
        self.url = url
    }
}

protocol AssetDownloadsSession {
    @discardableResult
    func scheduleDownload(for url: URL,
                          completionHandler: @escaping DownloadCompletionHandler) -> DownloadToken
    func pauseDownload(_ token: DownloadToken)
}

final class DefaultAssetDownloadsSession: NSObject, AssetDownloadsSession {
    private final class Download {
        let url: URL
        
        private(set) var completionHandlers: [DownloadToken: DownloadCompletionHandler]
        private(set) var stage: DownloadStage = .ready
        private(set) var task: URLSessionDownloadTaskType?
        private(set) var resumptionData: Data?
        
        // MARK: - Init
        
        init(url: URL,
             completionHandler: @escaping DownloadCompletionHandler,
             for token: DownloadToken) {
            self.url = url
            self.completionHandlers = [token: completionHandler]
        }
        
        // MARK: - Coalescing
        
        //a token is unique per caller, so this coalesces onto the download rather than
        //replacing whoever is already waiting on it
        func addCoalescedCompletionHandler(_ completionHandler: @escaping DownloadCompletionHandler,
                                           for token: DownloadToken) {
            completionHandlers[token] = completionHandler
        }
        
        //`true` when the token was one of ours
        @discardableResult
        func removeCoalescedCompletionHandler(for token: DownloadToken) -> Bool {
            completionHandlers.removeValue(forKey: token) != nil
        }
        
        // MARK: - Stage
        
        func started(with task: URLSessionDownloadTaskType) {
            stage = .running
            self.task = task
            resumptionData = nil
        }
        
        func pausing() -> URLSessionDownloadTaskType? {
            guard stage == .running,
                  let task = task else {
                return nil
            }
            
            stage = .pausing
            
            return task
        }
        
        func paused(with resumptionData: Data) {
            stage = .paused
            self.resumptionData = resumptionData
            task = nil
        }
    }
    
    private enum DownloadStage {
        case ready                            //constructed, no task yet - lives for one `sync` block
        case running
        case pausing                          //cancel issued, resumption data hasn't landed yet
        case paused
    }
    
    //one entry per URL - everybody who wants it shares the same download
    private var downloads = [URL: Download]()
    private let queue = DispatchQueue(label: "com.williamboles.downloadssession")
    
    private var session: URLSessionType!
    private let memoryPressureMonitor: MemoryPressureMonitor
    
    // MARK: - Singleton
    
    static let shared = DefaultAssetDownloadsSession()
    
    // MARK: - Init
    
    init(urlSessionFactory: URLSessionFactoryType = URLSessionFactory(),
         memoryPressureMonitor: MemoryPressureMonitor = DefaultMemoryPressureMonitor()) {
        self.memoryPressureMonitor = memoryPressureMonitor
        
        super.init()
        
        self.session = urlSessionFactory.defaultSession(delegate: self)
        
        memoryPressureMonitor.startMonitoring { [weak self] in
            self?.purgePausedDownloads()
        }
    }
    
    // MARK: - ThreadSafety
    
    //`downloads` is only ever reached from inside here, so a read-modify-write of it
    //stays indivisible.
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
    
    // MARK: - Schedule
    
    @discardableResult
    func scheduleDownload(for url: URL,
                          completionHandler: @escaping DownloadCompletionHandler) -> DownloadToken {
        let token = DownloadToken(url: url)
        
        sync {
            if let download = downloads[url] {
                coalesceWithExistingDownload(download,
                                             completionHandler: completionHandler,
                                             for: token)
            } else {
                scheduleNewDownload(for: url,
                                    completionHandler: completionHandler,
                                    token: token)
            }
        }
        
        return token
    }
    
    private func scheduleNewDownload(for url: URL,
                                     completionHandler: @escaping DownloadCompletionHandler,
                                     token: DownloadToken) {
        dispatchPrecondition(condition: .onQueue(queue))
        
        let download = Download(url: url,
                                completionHandler: completionHandler,
                                for: token)
        downloads[url] = download
        
        startDownload(download,
                      resumingFrom: nil)
    }
    
    private func coalesceWithExistingDownload(_ download: Download,
                                              completionHandler: @escaping DownloadCompletionHandler,
                                              for token: DownloadToken) {
        dispatchPrecondition(condition: .onQueue(queue))
        
        //a download for `url` already exists so coalescing this new request with it
        download.addCoalescedCompletionHandler(completionHandler,
                                               for: token)
        
        //a paused download is the only one with nothing already on its way
        guard download.stage == .paused else {
            os_log(.info, "Joining an existing active download of: %{public}@", download.url.absoluteString)
            
            return
        }
        
        startDownload(download,
                      resumingFrom: download.resumptionData)
    }
    
    private func startDownload(_ download: Download,
                               resumingFrom resumptionData: Data?) {
        dispatchPrecondition(condition: .onQueue(queue))
        
        let task: URLSessionDownloadTaskType
        if let resumptionData = resumptionData {
            os_log(.info, "Resuming an existing paused download: %{public}@", download.url.absoluteString)
            task = session.downloadTask(withResumeData: resumptionData)
        } else {
            os_log(.info, "Creating a new download: %{public}@", download.url.absoluteString)
            task = session.downloadTask(with: download.url)
        }
        
        download.started(with: task)
        
        task.resume()
    }
    
    // MARK: - Pause
    
    func pauseDownload(_ token: DownloadToken) {
        let url = token.url
        
        let taskToPause = sync { () -> URLSessionDownloadTaskType? in
            guard let download = downloads[url],
                  download.removeCoalescedCompletionHandler(for: token) else {
                return nil
            }
            
            guard download.completionHandlers.isEmpty else {
                os_log(.info, "Dropping a caller from a download others still want: %{public}@", url.absoluteString)
                return nil
            }
            
            guard let task = download.pausing() else {
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
            
            guard download.completionHandlers.isEmpty else {
                os_log(.info, "Restarting download: %{public}@", url.absoluteString)
                
                //whilst this download was being paused, another request came in for download so restart the download
                startDownload(download,
                              resumingFrom: resumptionData)
                return
            }
            
            guard let resumptionData = resumptionData else {
                os_log(.info, "Dropping a paused download that produced no resumption data: %{public}@", url.absoluteString)
                
                downloads[url] = nil
                return
            }
            
            os_log(.info, "Cancelled download task has produced resumption data of: %{public}@ for %{public}@", resumptionData.description, url.absoluteString)
            
            download.paused(with: resumptionData)
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
        let result: Result<Data, Error>
        do {
            result = .success(try Data(contentsOf: location))
        } catch let error {
            result = .failure(NetworkingError.invalidData(underlyingError: error))
        }
        
        os_log(.info, "Download completed for: %{public}@", url.absoluteString)
        
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
        
        os_log(.info, "Download failed for: %{public}@ with error: %{public}@", url.absoluteString, error.localizedDescription)
        
        deliverResult(.failure(NetworkingError.retrieval(underlyingError: error)),
                      for: url,
                      taskIdentifier: taskIdentifier)
    }
    
    //the result is made once and handed to everybody who coalesced onto this download
    private func deliverResult(_ result: Result<Data, Error>,
                               for url: URL,
                               taskIdentifier: Int) {
        //get all completionHandlers for this url
        let completionHandlers = sync { () -> [DownloadCompletionHandler] in
            guard let download = downloads[url] else {
                os_log(.info, "Ignoring an unknown download: %{public}@", url.absoluteString)
                return []
            }
            
            //nothing should be in flight whilst pausing or paused
            guard download.stage == .running else {
                os_log(.info, "Ignoring a download that isn't running: %{public}@", url.absoluteString)
                return []
            }
            
            //a task this download has since replaced, winding down late
            guard download.task?.taskIdentifier == taskIdentifier else {
                os_log(.info, "Ignoring download where the task has been replaced: %{public}d", taskIdentifier)
                return []
            }
            
            downloads[url] = nil
            
            return Array(download.completionHandlers.values)
        }
        
        // can't happen within `sync` in case the callee blocks the thread
        completionHandlers.forEach { $0(result) }
    }
}

extension DefaultAssetDownloadsSession: URLSessionDownloadDelegate {
    
    // MARK: - URLSessionDownloadDelegate
    
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let url = downloadTask.originalRequest?.url else {
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
        guard let url = downloadTask.originalRequest?.url else {
            return
        }
        
        handleResumption(for: url,
                         fileOffset: fileOffset,
                         expectedTotalBytes: expectedTotalBytes)
    }
    
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let url = downloadTask.originalRequest?.url else {
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
              let url = task.originalRequest?.url else {
            return
        }
        
        handleFailedDownloading(for: url,
                                taskIdentifier: task.taskIdentifier,
                                error: error)
    }
}

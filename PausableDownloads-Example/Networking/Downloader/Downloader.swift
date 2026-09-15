//
//  Downloader.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 14/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation
import os

typealias DownloadCompletionHandler = (Result<Data, Error>) -> ()

struct DownloadToken: Hashable {
    let url: URL
    
    private let id = UUID()
    
    init(url: URL) {
        self.url = url
    }
}

enum DownloadError: Error {
    case failed(underlyingError: Error?)
    case invalidData(underlyingError: Error?)
}

protocol Downloader {
    @discardableResult
    func download(_ url: URL,
                  completionHandler: @escaping DownloadCompletionHandler) -> DownloadToken
    func pause(_ token: DownloadToken)
}

final class DefaultDownloader: NSObject, Downloader {
    private final class Download {
        enum DownloadStage {
            case ready                            //constructed, no task yet - lives for one `sync` block
            case running(DownloadTask)
            case pausing                          //cancel issued, resumption data hasn't landed yet
            case paused(resumptionData: Data)
        }
        
        let url: URL
        
        private(set) var completionHandlers = [DownloadToken: DownloadCompletionHandler]()
        private(set) var stage: DownloadStage = .ready
        
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
        
        func remove(_ token: DownloadToken) -> Bool {
            completionHandlers.removeValue(forKey: token) != nil
        }
        
        // MARK: - Stage
        
        func markRunning(with task: DownloadTask) {
            stage = .running(task)
        }
        
        //returns the task to cancel, or `nil` if there isn't one running
        func markPausing() -> DownloadTask? {
            guard case .running(let task) = stage else {
                return nil
            }
            
            stage = .pausing
            
            return task
        }
        
        func markPaused(with resumptionData: Data) {
            stage = .paused(resumptionData: resumptionData)
        }
    }
    
    //one entry per URL - everybody who wants it coalesces onto the same download
    private var downloads = [URL: Download]()
    private let queue = DispatchQueue(label: "com.williamboles.downloader")
    
    private let sessionFactory: DownloadSessionFactory
    private lazy var session: DownloadSession = sessionFactory.makeSession(delegate: self)
    private let memoryPressureMonitor: MemoryPressureMonitor
    
    // MARK: - Singleton
    
    static let shared = DefaultDownloader()
    
    // MARK: - Init
    
    init(sessionFactory: DownloadSessionFactory = DefaultDownloadSessionFactory(),
         memoryPressureMonitor: MemoryPressureMonitor = DefaultMemoryPressureMonitor()) {
        self.sessionFactory = sessionFactory
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
            
            downloads = downloads.filter {
                if case .paused = $0.value.stage {
                    return false
                }
                
                return true
            }
        }
    }
    
    // MARK: - Download
    
    @discardableResult
    func download(_ url: URL,
                  completionHandler: @escaping DownloadCompletionHandler) -> DownloadToken {
        let token = DownloadToken(url: url)
        
        sync {
            let download = downloads[url] ?? registerDownload(for: url)
            download.add(completionHandler, for: token)
            
            switch download.stage {
            case .ready, .paused:
                startDownload(download)
            case .running, .pausing:
                os_log(.info, "Coalescing download request onto an existing running download: %{public}@", url.absoluteString)
            }
        }
        
        return token
    }
    
    private func registerDownload(for url: URL) -> Download {
        dispatchPrecondition(condition: .onQueue(queue))
        
        let download = Download(url: url)
        downloads[url] = download
        
        return download
    }
    
    private func startDownload(_ download: Download) {
        dispatchPrecondition(condition: .onQueue(queue))
        
        let task: DownloadTask
        if case .paused(let resumptionData) = download.stage {
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
        
        let taskToPause: DownloadTask? = sync {
            guard let download = downloads[url] else {
                os_log(.info, "Download not found for URL: %{public}@", url.absoluteString)
                
                return nil
            }
            
            guard download.remove(token) else {
                os_log(.info, "Token doesn't belong to the download of: %{public}@", url.absoluteString)
                
                return nil
            }
            
            guard download.completionHandlers.isEmpty else {
                os_log(.info, "Dropping a coalesced caller from a download others still want: %{public}@", url.absoluteString)
                
                return nil
            }
            
            guard let task = download.markPausing() else {
                //the download is already pausing or paused, so there's no task to cancel.
                //The caller has been removed, so when the resumption data lands
                //`finishPausing` will find nobody waiting and leave the download paused
                os_log(.info, "Download isn't running so there is nothing to pause: %{public}@", url.absoluteString)
                
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
            guard let download = downloads[url] else {
                os_log(.info, "Can't find the download being paused: %{public}@", url.absoluteString)
                
                return
            }
            
            guard case .pausing = download.stage else {
                os_log(.info, "Download is no longer pausing: %{public}@", url.absoluteString)
                
                return
            }
            
            //two things decide what happens next: whether the cancelled task managed to
            //produce resumption data, and whether anybody asked for this download whilst
            //it was being paused
            switch (resumptionData, !download.completionHandlers.isEmpty) {
            case (.some(let resumptionData), false):
                os_log(.info, "Paused download with %{public}d bytes of resumption data: %{public}@", resumptionData.count, url.absoluteString)
                
                download.markPaused(with: resumptionData)
                
            case (.some(let resumptionData), true):
                os_log(.info, "Restarting download from %{public}d bytes of resumption data: %{public}@", resumptionData.count, url.absoluteString)
                
                download.markPaused(with: resumptionData)
                startDownload(download)
                
            case (nil, true):
                //nothing to resume from, so the new caller gets a download from scratch
                os_log(.info, "Restarting download from scratch as pausing produced no resumption data: %{public}@", url.absoluteString)
                
                startDownload(download)
                
            case (nil, false):
                //nothing to resume from and nobody waiting - keeping the entry would leave it
                //stuck at `pausing`, where the next caller would coalesce onto it and never
                //be answered
                os_log(.error, "Dropping a pausing download that produced no resumption data: %{public}@", url.absoluteString)
                
                downloads[url] = nil
            }
        }
    }
    
    // MARK: - DelegateHandling
    
    func handleProgress(for url: URL,
                        totalBytesWritten: Int64,
                        expectedTotalBytes: Int64) {
        //`URLSession` reports `NSURLSessionTransferSizeUnknown` (-1) when the server
        //doesn't say how big the file is
        guard expectedTotalBytes > 0 else {
            os_log(.info, "Downloaded %{public}lld bytes of %{public}@ (total size unknown)", totalBytesWritten, url.absoluteString)
            
            return
        }
        
        let downloadedPercentage = (Double(totalBytesWritten)/Double(expectedTotalBytes)) * 100
        os_log(.info, "Downloaded %{public}.02f%% of %{public}@", downloadedPercentage, url.absoluteString)
    }
    
    func handleResumption(for url: URL,
                          fileOffset: Int64,
                          expectedTotalBytes: Int64) {
        guard expectedTotalBytes > 0 else {
            os_log(.info, "Resuming download: %{public}@ from: %{public}lld bytes (total size unknown)", url.absoluteString, fileOffset)
            
            return
        }
        
        let resumptionPercentage = (Double(fileOffset)/Double(expectedTotalBytes)) * 100
        os_log(.info, "Resuming download: %{public}@ from: %{public}.02f%%", url.absoluteString, resumptionPercentage)
    }
    
    //once the download has been removed it is finished whatever happens next, so a file
    //that can't be read is delivered as a failure rather than left lingering
    func handleFinishedDownloading(for url: URL,
                                   taskIdentifier: Int,
                                   to location: URL) {
        guard let download = removeRunningDownload(for: url,
                                                   taskIdentifier: taskIdentifier) else {
            return
        }
        
        //`location` is only valid until this delegate call returns, so read it now
        let result: Result<Data, Error>
        do {
            result = .success(try Data(contentsOf: location))
            
            os_log(.info, "Download completed for: %{public}@", url.absoluteString)
        } catch let error {
            result = .failure(DownloadError.invalidData(underlyingError: error))
            
            os_log(.error, "Download completed for: %{public}@ but its file could not be read: %{public}@", url.absoluteString, error.localizedDescription)
        }
        
        deliverResult(result,
                      for: download)
    }
    
    func handleFailedDownloading(for url: URL,
                                 taskIdentifier: Int,
                                 error: Error) {
        //a pause or a purge cancels the task; that isn't a failure anybody asked about
        if let error = error as? URLError, error.code == .cancelled {
            os_log(.info, "Ignoring the cancellation of task: %{public}d", taskIdentifier)
            
            return
        }
        
        guard let download = removeRunningDownload(for: url,
                                                   taskIdentifier: taskIdentifier) else {
            return
        }
        
        os_log(.error, "Download failed for: %{public}@ with error: %{public}@", url.absoluteString, error.localizedDescription)
        
        deliverResult(.failure(DownloadError.failed(underlyingError: error)),
                      for: download)
    }
    
    private func removeRunningDownload(for url: URL,
                                       taskIdentifier: Int) -> Download? {
        sync {
            guard let download = downloads[url] else {
                os_log(.info, "Download not found for URL: %{public}@", url.absoluteString)
                
                return nil
            }
            
            guard case .running(let task) = download.stage else {
                os_log(.info, "Download isn't running: %{public}@", url.absoluteString)
                
                return nil
            }
            
            guard task.taskIdentifier == taskIdentifier else {
                os_log(.info, "Download isn't associated with task: %{public}d", taskIdentifier)
                
                return nil
            }

            downloads[url] = nil

            return download
        }
    }
    
    //the result is made once and handed to everybody who coalesced onto the download.
    //Can't happen within `sync` in case a callee blocks the thread - and doesn't need to,
    //as the download has already been removed so nobody else can be touching it
    private func deliverResult(_ result: Result<Data, Error>,
                               for download: Download) {
        download.completionHandlers.values.forEach { $0(result) }
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

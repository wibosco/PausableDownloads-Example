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
    func scheduleDownload(url: URL,
                          completionHandler: @escaping DownloadCompletionHandler) -> DownloadToken
    func pauseDownload(_ token: DownloadToken)
}

final class DefaultAssetDownloadsSession: NSObject, AssetDownloadsSession {
    private struct Download {
        var handlers: [DownloadToken: DownloadCompletionHandler]
        var stage: DownloadStage
    }
    
    private enum DownloadStage {
        case running(task: URLSessionDownloadTaskType)
        case pausing                          //cancel issued, resumption data hasn't landed yet
        case paused(resumptionData: Data)
        
        var isPaused: Bool {
            guard case .paused = self else {
                return false
            }
            
            return true
        }
    }
    
    //one entry per URL - everybody who wants it shares the one download
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
    
    // MARK: - State
    
    //`downloads` is only ever reached from inside here, so a read-modify-write of it
    //stays indivisible.
    private func sync<T>(_ body: () -> T) -> T {
        //`sync` isn't reentrant - trap on a nested call rather than deadlock
        dispatchPrecondition(condition: .notOnQueue(queue))
        
        return queue.sync(execute: body)
    }
    
    //only a running download owns a task, so only a running download can be matched by one
    private func runningDownload(withTaskIdentifier taskIdentifier: Int) -> (url: URL, download: Download)? {
        dispatchPrecondition(condition: .onQueue(queue))
        
        return downloads.first { entry in
            guard case let .running(task) = entry.value.stage else {
                return false
            }
            
            return task.taskIdentifier == taskIdentifier
        }.map { (url: $0.key, download: $0.value) }
    }
    
    // MARK: - MemoryPressure
    
    private func purgePausedDownloads() {
        sync {
            os_log(.info, "Purging paused items under memory pressure")
            
            downloads = downloads.filter { !$0.value.stage.isPaused }
        }
    }
    
    // MARK: - Schedule
    
    @discardableResult
    func scheduleDownload(url: URL,
                          completionHandler: @escaping DownloadCompletionHandler) -> DownloadToken {
        let token = DownloadToken(url: url)
        
        sync {
            guard var download = downloads[url] else {
                startDownload(for: url,
                              resumingFrom: nil,
                              handlers: [token: completionHandler])
                return
            }
            
            //a download for `url` already exists so coalescing this new request with it
            download.handlers[token] = completionHandler
            
            //a paused download is the only one with nothing already on its way
            guard case let .paused(resumptionData) = download.stage else {
                os_log(.info, "Joining an existing download of: %{public}@", url.absoluteString)
                
                downloads[url] = download
                return
            }
            
            startDownload(for: url,
                          resumingFrom: resumptionData,
                          handlers: download.handlers)
        }
        
        return token
    }
    
    //Deciding to start a task and recording it both happen on the queue, so they can't be
    //split apart by another caller. Replacing the whole entry is what makes resumption data
    //single use - starting a task overwrites the stage holding it.
    private func startDownload(for url: URL,
                               resumingFrom resumptionData: Data?,
                               handlers: [DownloadToken: DownloadCompletionHandler]) {
        dispatchPrecondition(condition: .onQueue(queue))
        
        let task: URLSessionDownloadTaskType
        if let resumptionData = resumptionData {
            os_log(.info, "Resuming an existing download: %{public}@", url.absoluteString)
            task = session.downloadTask(withResumeData: resumptionData)
        } else {
            os_log(.info, "Creating a new download: %{public}@", url.absoluteString)
            task = session.downloadTask(with: url)
        }
        
        downloads[url] = Download(handlers: handlers,
                                  stage: .running(task: task))
        
        //`URLSession` delivers its callbacks on its own queue, never synchronously on this
        //thread, so holding the downloads queue here can't deadlock the way a cancel would
        task.resume()
    }
    
    // MARK: - Pause
    
    func pauseDownload(_ token: DownloadToken) {
        let url = token.url
        
        let taskToPause = sync { () -> URLSessionDownloadTaskType? in
            //Pausing drops the caller - it isn't a result anybody is waiting to hear. A
            //token that isn't in there has already been dropped, so there's nothing to do.
            guard var download = downloads[url],
                  download.handlers.removeValue(forKey: token) != nil else {
                return nil
            }
            
            //write the entry back whichever way we leave, so no return can half-update it
            defer { downloads[url] = download }
            
            //somebody else still wants this URL, so the download carries on
            guard download.handlers.isEmpty else {
                os_log(.info, "Dropping a caller from a download others still want: %{public}@", url.absoluteString)
                return nil
            }
            
            //a cancel that's already in flight will produce the resumption data on its own
            guard case let .running(task) = download.stage else {
                return nil
            }
            
            os_log(.info, "Pausing download: %{public}@", url.absoluteString)
            
            download.stage = .pausing
            
            return task
        }
        
        guard let taskToPause = taskToPause else {
            return
        }
        
        //`URLSession` can answer on the thread that cancelled, so the downloads queue
        //mustn't be held here
        taskToPause.cancel(byProducingResumeData: { [weak self] data in
            self?.handleResumptionData(data,
                                       for: url)
        })
    }
    
    private func handleResumptionData(_ data: Data?,
                                      for url: URL) {
        sync {
            //only a pause we issued can be answered here, and only once
            guard var download = downloads[url],
                  case .pausing = download.stage else {
                os_log(.info, "Ignoring resumption data for a download that is no longer pausing: %{public}@", url.absoluteString)
                return
            }
            
            guard !download.handlers.isEmpty else {
                //nobody's waiting, so park the data if there is any and forget the download if there isn't
                if let data = data {
                    os_log(.info, "Cancelled download task has produced resumption data of: %{public}@ for %{public}@", data.description, url.absoluteString)
                    
                    download.stage = .paused(resumptionData: data)
                    downloads[url] = download
                } else {
                    downloads[url] = nil
                }
                
                return
            }
            
            os_log(.info, "Resumption data has landed so starting the download somebody joined: %{public}@", url.absoluteString)
            
            //somebody asked for this URL whilst the pause was in flight
            startDownload(for: url,
                          resumingFrom: data,
                          handlers: download.handlers)
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
    
    func handleFinishedDownloading(forTaskWith taskIdentifier: Int,
                                   to location: URL) {
        deliverResult(forTaskWith: taskIdentifier) {
            do {
                return .success(try Data(contentsOf: location))
            } catch let error {
                return .failure(NetworkingError.invalidData(underlyingError: error))
            }
        }
    }
    
    func handleComplete(forTaskWith taskIdentifier: Int,
                        error: Error?) {
        //a pause or a purge cancels the task; that isn't a failure anybody asked about
        if let error = error as? URLError, error.code == .cancelled {
            os_log(.info, "Ignoring the cancellation of task: %{public}d", taskIdentifier)
            return
        }
        
        deliverResult(forTaskWith: taskIdentifier) {
            .failure(NetworkingError.retrieval(underlyingError: error))
        }
    }
    
    private func deliverResult(forTaskWith taskIdentifier: Int,
                               _ makeResult: () -> Result<Data, Error>) {
        let handlers = sync { () -> [DownloadCompletionHandler] in
            //a download that has already been delivered went with the entry that held it
            guard let running = runningDownload(withTaskIdentifier: taskIdentifier) else {
                return []
            }
            
            os_log(.info, "Finished download of: %{public}@", running.url.absoluteString)
            
            //the download is over for everybody who asked for it, so the entry goes with it
            downloads[running.url] = nil
            
            return Array(running.download.handlers.values)
        }
        
        guard !handlers.isEmpty else {
            return
        }
        
        //made once and handed to everybody who coalesced onto this download
        let result = makeResult()
        
        handlers.forEach { $0(result) }
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
        handleFinishedDownloading(forTaskWith: downloadTask.taskIdentifier, to: location)
    }
    
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        handleComplete(forTaskWith: task.taskIdentifier, error: error)
    }
}

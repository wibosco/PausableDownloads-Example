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
    private let id = UUID()
}

enum DownloadError: Error {
    case cancelled
    case transportFailure(Error)
    case invalidResponse
    case unacceptableStatusCode(Int)
    case fileReadFailed(Error)
}

protocol Downloader {
    @discardableResult
    func download(_ url: URL,
                  completionHandler: @escaping DownloadCompletionHandler) -> DownloadToken
    func cancel(_ token: DownloadToken)
}

final class DefaultDownloader: NSObject, Downloader {
    private final class Download {
        let task: DownloadTask
        var completionHandlers = [DownloadToken: DownloadCompletionHandler]()
        
        // MARK: - Init
        
        init(task: DownloadTask) {
            self.task = task
        }
    }
    
    //only downloads with a running task - one entry per URL, so everybody who wants it
    //coalesces onto the same download
    private var downloads = [URL: Download]()
    private var resumptionData = [URL: Data]()
    
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
    
    //`downloads` and `resumptionData` are only ever reached from inside here, so a
    //read-modify-write of them stays indivisible
    private func sync<T>(_ body: () -> T) -> T {
        //`sync` isn't reentrant - trap on a nested call rather than deadlock
        dispatchPrecondition(condition: .notOnQueue(queue))
        
        return queue.sync(execute: body)
    }
    
    // MARK: - MemoryPressure
    
    private func purgePausedDownloads() {
        sync {
            os_log(.info, "Purging paused downloads under memory pressure")
            
            resumptionData.removeAll()
        }
    }
    
    // MARK: - Download
    
    @discardableResult
    func download(_ url: URL,
                  completionHandler: @escaping DownloadCompletionHandler) -> DownloadToken {
        let token = DownloadToken()
        
        sync {
            let download: Download
            if let existingDownload = downloads[url] {
                os_log(.info, "Coalescing onto an existing download of: %{public}@", url.absoluteString)
                
                download = existingDownload
            } else {
                download = Download(task: startTask(for: url))
                downloads[url] = download
            }
            
            //a token is unique per caller, so this adds to whoever is already waiting
            //rather than replacing them
            download.completionHandlers[token] = completionHandler
        }
        
        return token
    }
    
    private func startTask(for url: URL) -> DownloadTask {
        dispatchPrecondition(condition: .onQueue(queue))
        
        let task: DownloadTask
        if let resumptionData = resumptionData.removeValue(forKey: url) {
            os_log(.info, "Resuming a paused download: %{public}@", url.absoluteString)
            
            task = session.downloadTask(withResumeData: resumptionData)
        } else {
            os_log(.info, "Starting a new download: %{public}@", url.absoluteString)
            
            task = session.downloadTask(with: url)
        }
        
        task.resume()
        
        return task
    }
    
    // MARK: - Cancel
    
    //to the caller this is a cancel, but internally the download is paused so that
    //nothing already downloaded is thrown away
    func cancel(_ token: DownloadToken) {
        let (completionHandler, pausedDownload): (DownloadCompletionHandler?, (task: DownloadTask, url: URL)?) = sync {
            //a token belongs to at most one download, so the first match is the one
            guard let (url, download) = downloads.first(where: { $0.value.completionHandlers[token] != nil }),
                  let completionHandler = download.completionHandlers.removeValue(forKey: token) else {
                //download already completed, so there is nobody to tell
                os_log(.info, "Token isn't waiting on a download")

                return (nil, nil)
            }

            guard download.completionHandlers.isEmpty else {
                os_log(.info, "Dropping a coalesced caller from a download others still want: %{public}@", url.absoluteString)

                return (completionHandler, nil)
            }

            //nobody is left waiting so clear out download
            downloads[url] = nil

            return (completionHandler, (download.task, url))
        }

        if let pausedDownload {
            os_log(.info, "Pausing download: %{public}@", pausedDownload.url.absoluteString)

            pausedDownload.task.cancel(byProducingResumeData: { [weak self] resumptionData in
                self?.storeResumptionData(resumptionData,
                                          for: pausedDownload.url)
            })
        }
        
        //only this caller is told - anybody else coalesced onto the download is still
        //waiting on it. Called off `queue` in case the caller blocks the thread
        completionHandler?(.failure(DownloadError.cancelled))
    }
    
    private func storeResumptionData(_ data: Data?,
                                     for url: URL) {
        sync {
            guard let data else {
                //nothing to resume from, so the next request starts from scratch
                os_log(.info, "Pausing produced no resumption data: %{public}@", url.absoluteString)
                
                return
            }
            
            //a request that arrived before the data did has already started from scratch,
            //so the data is of no use to it.
            //N.B. if that download is itself paused and its data lands before this data,
            //this older data will overwrite it - rare enough to accept, as resuming from it
            //fails with an error rather than leaving anybody waiting
            guard downloads[url] == nil else {
                os_log(.info, "Discarding resumption data as the download has already restarted: %{public}@", url.absoluteString)
                
                return
            }
            
            os_log(.info, "Paused download with %{public}d bytes of resumption data: %{public}@", data.count, url.absoluteString)
            
            resumptionData[url] = data
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
                                   statusCode: Int?,
                                   to location: URL) {
        guard let completionHandlers = clearDownload(for: url,
                                                     taskIdentifier: taskIdentifier) else {
            return
        }
        
        //only HTTP downloads are supported, so a response without a status code isn't
        //one that can be judged and is treated as a failure rather than taken on trust
        guard let statusCode else {
            os_log(.error, "Download completed for: %{public}@ without an HTTP response", url.absoluteString)
            
            let result: Result<Data, Error> = .failure(DownloadError.invalidResponse)
            completionHandlers.forEach { $0(result) }
            
            return
        }
        
        //`URLSession` only treats a transport failure as an error, so a non-2xx response
        //arrives here as though its body were the file that was asked for. A resumed task
        //completes with 206, so anything in the 2xx range is accepted rather than just 200
        guard (200..<300).contains(statusCode) else {
            os_log(.error, "Download failed for: %{public}@ with status code: %{public}d", url.absoluteString, statusCode)
            
            let result: Result<Data, Error> = .failure(DownloadError.unacceptableStatusCode(statusCode))
            completionHandlers.forEach { $0(result) }
            
            return
        }
        
        //`location` is only valid until this delegate call returns, so read it now
        let result: Result<Data, Error>
        do {
            result = .success(try Data(contentsOf: location))
            
            os_log(.info, "Download completed for: %{public}@", url.absoluteString)
        } catch let error {
            result = .failure(DownloadError.fileReadFailed(error))
            
            os_log(.error, "Download completed for: %{public}@ but its file could not be read: %{public}@", url.absoluteString, error.localizedDescription)
        }
        
        //the result is made once and handed to everybody who coalesced onto the download
        completionHandlers.forEach { $0(result) }
    }
    
    func handleFailedDownloading(for url: URL,
                                 taskIdentifier: Int,
                                 error: Error) {
        //a pause cancels the task; that isn't a failure anybody asked about
        if let error = error as? URLError, error.code == .cancelled {
            os_log(.info, "Ignoring the cancellation of task: %{public}d", taskIdentifier)
            
            return
        }
        
        guard let completionHandlers = clearDownload(for: url,
                                                     taskIdentifier: taskIdentifier) else {
            return
        }
        
        os_log(.error, "Download failed for: %{public}@ with error: %{public}@", url.absoluteString, error.localizedDescription)
        
        let result: Result<Data, Error> = .failure(DownloadError.transportFailure(error))
        completionHandlers.forEach { $0(result) }
    }
    
    // MARK: - CleanUp
    
    //the handlers are copied out whilst still on `queue` rather than the download being
    //returned - `Download` is a class, so reading it off `queue` would only be safe for as
    //long as nothing else kept hold of it
    private func clearDownload(for url: URL,
                               taskIdentifier: Int) -> [DownloadCompletionHandler]? {
        sync {
            guard let download = downloads[url] else {
                os_log(.info, "Unknown download: %{public}@", url.absoluteString)
                
                return nil
            }
            
            guard download.task.taskIdentifier == taskIdentifier else {
                os_log(.info, "Task isn't associated with download: %{public}d", taskIdentifier)
                
                return nil
            }
            
            downloads[url] = nil
            
            return Array(download.completionHandlers.values)
        }
    }
}

extension DefaultDownloader: URLSessionDownloadDelegate {
    
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
                                  statusCode: (downloadTask.response as? HTTPURLResponse)?.statusCode,
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

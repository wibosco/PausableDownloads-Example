//
//  DownloadSessionFactory.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 12/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation

//the parts of `URLSession` that a downloader needs, kept behind a protocol so tests can
//stand in for them
protocol DownloadSession {
    func downloadTask(with url: URL) -> DownloadTask
    func downloadTask(withResumeData resumeData: Data) -> DownloadTask
}

extension URLSession: DownloadSession {
    func downloadTask(with url: URL) -> DownloadTask {
        downloadTask(with: url) as URLSessionDownloadTask
    }
    
    func downloadTask(withResumeData resumeData: Data) -> DownloadTask {
        downloadTask(withResumeData: resumeData) as URLSessionDownloadTask
    }
}

protocol DownloadTask {
    var taskIdentifier: Int { get }
    
    func resume()
    func cancel(byProducingResumeData completionHandler: @escaping (Data?) -> Void)
}

extension URLSessionDownloadTask: DownloadTask { }

protocol DownloadSessionFactory {
    func makeSession(delegate: URLSessionDelegate) -> DownloadSession
}

final class DefaultDownloadSessionFactory: DownloadSessionFactory {
    
    // MARK: - Session
    
    func makeSession(delegate: URLSessionDelegate) -> DownloadSession {
        let configuration = URLSessionConfiguration.default
        
        //For demonstration purposes disable caching
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        
        return URLSession(configuration: configuration,
                          delegate: delegate,
                          delegateQueue: nil)
    }
}

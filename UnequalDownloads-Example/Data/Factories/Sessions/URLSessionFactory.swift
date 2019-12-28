//
//  URLSessionFactory.swift
//  DownloadStack-Example
//
//  Created by William Boles on 13/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

protocol URLSessionFactoryType {
    func defaultSession(delegate: URLSessionDelegate?, delegateQueue queue: OperationQueue?) -> URLSessionType
}

extension URLSessionFactoryType {
    func defaultSession(delegate: URLSessionDelegate? = nil, delegateQueue queue: OperationQueue? = nil) -> URLSessionType {
        return defaultSession(delegate: delegate, delegateQueue: queue)
    }
}

protocol URLSessionType {
    func downloadTask(with url: URL, completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTaskType
    func downloadTask(withResumeData resumeData: Data, completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTaskType
}

extension URLSession: URLSessionType {
    func downloadTask(with url: URL, completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTaskType {
        return downloadTask(with: url, completionHandler: completionHandler) as URLSessionDownloadTask
    }
    
    func downloadTask(withResumeData resumeData: Data, completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTaskType {
        return downloadTask(withResumeData: resumeData, completionHandler: completionHandler) as URLSessionDownloadTask
    }
}

protocol URLSessionDownloadTaskType {
    var progress: Progress { get }
    
    func resume()
    func cancel()
    func cancel(byProducingResumeData completionHandler: @escaping (Data?) -> Void)
}

extension URLSessionDownloadTask: URLSessionDownloadTaskType {}

class URLSessionFactory: URLSessionFactoryType {
    
    // MARK: - Default
    
    func defaultSession(delegate: URLSessionDelegate? = nil, delegateQueue queue: OperationQueue? = nil) -> URLSessionType {
        let configuration = URLSessionConfiguration.default
        
        //For demostration purposes disable caching
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
        
        return session
    }
}

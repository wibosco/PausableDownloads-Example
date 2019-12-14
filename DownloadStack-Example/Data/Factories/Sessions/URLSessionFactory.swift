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

protocol URLSessionType {
    func downloadTask(with url: URL) -> URLSessionDownloadTaskType
}

extension URLSession: URLSessionType {
    func downloadTask(with url: URL) -> URLSessionDownloadTaskType {
        return downloadTask(with: url) as URLSessionDownloadTask
    }
}

protocol URLSessionDownloadTaskType {
    var currentRequest: URLRequest? { get }
    
    func suspend()
    func resume()
    func cancel()
}

extension URLSessionDownloadTask: URLSessionDownloadTaskType {}


class URLSessionFactory: URLSessionFactoryType {
    
    // MARK: - Default
    
    func defaultSession(delegate: URLSessionDelegate?, delegateQueue queue: OperationQueue?) -> URLSessionType {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: queue)
        
        return session
    }
}

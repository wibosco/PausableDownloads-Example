//
//  MockURLSession.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 13/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

@testable import PausableDownloads_Example

class MockURLSession: URLSessionType {

    var downloadTask: MockURLSessionDownloadTask = MockURLSessionDownloadTask()
    var downloadTaskClosure: ((_ url: URL, _ completionHandler: @escaping ((URL?, URLResponse?, Error?) -> Void)) -> ())?
    var downloadTaskWithResumeDataClosure: ((_ resumeData: Data, _ completionHandler: @escaping ((URL?, URLResponse?, Error?) -> Void)) -> ())?
    
    func downloadTask(with url: URL, completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTaskType {
        downloadTaskClosure?(url, completionHandler)
        
        return downloadTask
    }
    
    func downloadTask(withResumeData resumeData: Data, completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTaskType {
        downloadTaskWithResumeDataClosure?(resumeData, completionHandler)
        
        return downloadTask
    }
}

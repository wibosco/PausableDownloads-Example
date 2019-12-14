//
//  MockURLSession.swift
//  DownloadStack-ExampleTests
//
//  Created by William Boles on 13/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

@testable import DownloadStack_Example

class MockURLSession: URLSessionType {
    
    var downloadTask: MockURLSessionDownloadTask = MockURLSessionDownloadTask()
    var downloadTaskClosure: ((_ url: URL) -> ())?
    
    func downloadTask(with url: URL) -> URLSessionDownloadTaskType {
        downloadTaskClosure?(url)
        
        return downloadTask
    }
}

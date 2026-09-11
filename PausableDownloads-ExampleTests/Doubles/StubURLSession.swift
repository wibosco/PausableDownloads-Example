//
//  StubURLSession.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 13/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

@testable import PausableDownloads_Example

class StubURLSession: URLSessionType {
    enum Event {
        case downloadTask(URL)
        case downloadTaskWithResumeData(Data)
    }
    
    private(set) var events = [Event]()
    
    var downloadTaskToReturn: StubURLSessionDownloadTask!
    var downloadTaskWithResumeDataToReturn: StubURLSessionDownloadTask!
    
    func downloadTask(with url: URL) -> URLSessionDownloadTaskType {
        events.append(.downloadTask(url))
        
        return downloadTaskToReturn
    }
    
    func downloadTask(withResumeData resumeData: Data) -> URLSessionDownloadTaskType {
        events.append(.downloadTaskWithResumeData(resumeData))
        
        return downloadTaskWithResumeDataToReturn
    }
}

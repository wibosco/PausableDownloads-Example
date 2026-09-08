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
        case downloadTask(URL, (URL?, URLResponse?, Error?) -> Void)
        case downloadTaskWithResumeData(Data, (URL?, URLResponse?, Error?) -> Void)
    }
    
    private(set) var events = [Event]()
    
    var downloadTaskToReturn: StubURLSessionDownloadTask!
    var downloadTaskWithResumeDataToReturn: StubURLSessionDownloadTask!
    
    func downloadTask(with url: URL, completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTaskType {
        events.append(.downloadTask(url, completionHandler))
        
        return downloadTaskToReturn
    }
    
    func downloadTask(withResumeData resumeData: Data,
                      completionHandler: @escaping (URL?, URLResponse?, Error?) -> Void) -> URLSessionDownloadTaskType {
        events.append(.downloadTaskWithResumeData(resumeData, completionHandler))
        
        return downloadTaskWithResumeDataToReturn
    }
}

//
//  StubURLSessionDownloadTask.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 13/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

@testable import PausableDownloads_Example

class StubURLSessionDownloadTask: URLSessionDownloadTaskType {
    enum Event {
        case resume
        case cancel
        case cancelByProducingResumeData((Data?) -> Void)
    }
    
    private(set) var events = [Event]()
    
    var progress: Progress = Progress()
    
    func resume() {
        events.append(.resume)
    }
    
    func cancel() {
        events.append(.cancel)
    }
    
    func cancel(byProducingResumeData completionHandler: @escaping (Data?) -> Void) {
        events.append(.cancelByProducingResumeData(completionHandler))
    }
}

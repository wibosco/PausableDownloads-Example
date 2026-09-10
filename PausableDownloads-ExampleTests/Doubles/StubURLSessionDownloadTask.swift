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
    
    private static var lastTaskIdentifier = 0
    
    private(set) var events = [Event]()
    
    let taskIdentifier: Int
    
    //set to report resumption data back on the thread that cancelled, rather than
    //handing the closure back to the test to call later
    var resumptionDataToProduceSynchronously: Data?
    
    // MARK: - Init
    
    init() {
        StubURLSessionDownloadTask.lastTaskIdentifier += 1
        taskIdentifier = StubURLSessionDownloadTask.lastTaskIdentifier
    }
    
    // MARK: - Task
    
    func resume() {
        events.append(.resume)
    }
    
    func cancel() {
        events.append(.cancel)
    }
    
    func cancel(byProducingResumeData completionHandler: @escaping (Data?) -> Void) {
        events.append(.cancelByProducingResumeData(completionHandler))
        
        if let resumptionDataToProduceSynchronously = resumptionDataToProduceSynchronously {
            completionHandler(resumptionDataToProduceSynchronously)
        }
    }
}

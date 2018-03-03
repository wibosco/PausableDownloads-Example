//
//  URLSessionDownloadTaskSpy.swift
//  DownloadStack-ExampleTests
//
//  Created by William Boles on 02/02/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

class URLSessionDownloadTaskSpy: URLSessionDownloadTask {
    
    var suspendWasCalled = false
    var resumeWasCalled = false
    var cancelWasCalled = false
    
    var currentRequestToBeReturned: URLRequest?
    
    override func suspend() {
        suspendWasCalled = true
    }
    
    override func resume() {
        resumeWasCalled = true
    }
    
    override func cancel() {
        cancelWasCalled = true
    }
    
    override var currentRequest: URLRequest? {
        return currentRequestToBeReturned
    }
}

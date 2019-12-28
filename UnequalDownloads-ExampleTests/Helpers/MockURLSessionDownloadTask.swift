//
//  MockURLSessionDownloadTask.swift
//  UnequalDownloads-ExampleTests
//
//  Created by William Boles on 13/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

@testable import UnequalDownloads_Example

class MockURLSessionDownloadTask: URLSessionDownloadTaskType {
    var progress: Progress = Progress()
    
    var resumeClosure: (() -> ())?
    var cancelClosure: (() -> ())?
    var cancelByProducingResumeDataClosure: ((_ completionHandler: ((Data?) -> Void)) -> ())?
    
    func resume() {
        resumeClosure?()
    }
    
    func cancel() {
        cancelClosure?()
    }
    
    func cancel(byProducingResumeData completionHandler: @escaping (Data?) -> Void) {
        cancelByProducingResumeDataClosure?(completionHandler)
    }
}

//
//  AssetDownloadItemTests.swift
//  DownloadStack-ExampleTests
//
//  Created by William Boles on 28/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import XCTest

@testable import DownloadStack_Example

class AssetDownloadItemTests: XCTestCase {
    
    // MARK: - Lifecycle
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Tests
    
    // MARK: Pause
    
    func test_pause_taskSuspended() {
        let spy = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: spy)
        item.pause()
        
        XCTAssertTrue(spy.suspendWasCalled)
    }
    
    func test_pause_state() {
        let task = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: task)
        item.pause()
        
        XCTAssertFalse(item.forceDownload)
        XCTAssertEqual(item.status, Status.waiting)
    }
    
    func test_pause_forceDownloadSetToFalse() {
        let task = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: task)
        item.forceDownload = true
        item.pause()
        
        XCTAssertFalse(item.forceDownload)
    }
    
    // MARK: Resume
    
    func test_resume_taskResumed() {
        let spy = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: spy)
        item.resume()
        
        XCTAssertTrue(spy.resumeWasCalled)
    }
    
    func test_resume_state() {
        let task = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: task)
        item.resume()
        
        XCTAssertEqual(item.status, Status.downloading)
    }
    
    func test_resume_forceDownloadTrue() {
        let task = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: task)
        item.forceDownload = true
        item.resume()
        
        XCTAssertTrue(item.forceDownload)
    }
    
    func test_resume_forceDownloadFalse() {
        let task = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: task)
        item.forceDownload = false
        item.resume()
        
        XCTAssertFalse(item.forceDownload)
    }
    
    // MARK: SoftCancel
    
    func test_softCancel_taskResumed() {
        let spy = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: spy)
        item.softCancel()
        
        XCTAssertTrue(spy.suspendWasCalled)
    }
    
    func test_softCancel_state() {
        let task = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: task)
        item.softCancel()
        
        XCTAssertEqual(item.status, Status.suspended)
    }
    
    func test_softCancel_forceDownloadTrue() {
        let task = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: task)
        item.forceDownload = true
        item.softCancel()
        
        XCTAssertFalse(item.forceDownload)
    }
    
    func test_softCancel_forceDownloadFalse() {
        let task = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: task)
        item.forceDownload = false
        item.softCancel()
        
        XCTAssertFalse(item.forceDownload)
    }
    
    // MARK: HardCancel
    
    func test_hardCancel_taskResumed() {
        let spy = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: spy)
        item.hardCancel()
        
        XCTAssertTrue(spy.cancelWasCalled)
    }
    
    func test_hardCancel_state() {
        let task = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: task)
        item.hardCancel()
        
        XCTAssertEqual(item.status, Status.canceled)
    }
    
    func test_hardCancel_forceDownloadTrue() {
        let task = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: task)
        item.forceDownload = true
        item.hardCancel()
        
        XCTAssertFalse(item.forceDownload)
    }
    
    func test_hardCancel_forceDownloadFalse() {
        let task = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: task)
        item.forceDownload = false
        item.hardCancel()
        
        XCTAssertFalse(item.forceDownload)
    }
    
    // MARK: URL
    
    func test_url_matches() {
        let session = URLSession.shared
        let url = URL(string: "http://test.com")!
        let task = session.downloadTask(with: url)
        
        let item = AssetDownloadItem(task: task)
        
        XCTAssertEqual(url, item.url)
    }
    
    // MARK: Coalesce
    
    func test_coalesce_mutlipleSuccessCallbacksTriggered() {
        let task = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: task)
        
        let expectedData = "this is a test".data(using: .utf8)!
        
        let expectationA = expectation(description: "Closure called")
        let completionHandlerA: AssetDownloadItemCompletionHandler = { result in
            switch result {
            case .success(let data):
                XCTAssertEqual(data, expectedData)
            default:
                XCTFail()
            }
            expectationA.fulfill()
        }
        
        let expectationB = expectation(description: "Closure called")
        let completionHandlerB: AssetDownloadItemCompletionHandler = { result in
            switch result {
            case .success(let data):
                XCTAssertEqual(data, expectedData)
            default:
                XCTFail()
            }
            expectationB.fulfill()
        }
        
        item.completionHandler = completionHandlerA
        item.coalesce(completionHandlerB)
        
        item.completionHandler?(Result<Data>.success(expectedData))
        
        waitForExpectations(timeout: 2) { (error) in
        }
    }
    
    func test_coalesce_mutlipleFailureCallbacksTriggered() {
        let task = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: task)
        
        let expectationA = expectation(description: "Closure called")
        let completionHandlerA: AssetDownloadItemCompletionHandler = { result in
            switch result {
            case .failure(_):
                break
            default:
                XCTFail()
            }
            expectationA.fulfill()
        }
        
        let expectationB = expectation(description: "Closure called")
        let completionHandlerB: AssetDownloadItemCompletionHandler = { result in
            switch result {
            case .failure(_):
                break
            default:
                XCTFail()
            }
            expectationB.fulfill()
        }
        
        item.completionHandler = completionHandlerA
        item.coalesce(completionHandlerB)
        
        item.completionHandler?(Result<Data>.failure(APIError.invalidData))
        
        waitForExpectations(timeout: 2) { (error) in
        }
    }
    
    func test_coalesce_additionalCallbackTriggeredWhenNoInitialOneExists() {
        let task = URLSessionDownloadTaskSpy()
        
        let item = AssetDownloadItem(task: task)
        
        let expectedData = "this is a test".data(using: .utf8)!
        
        let callbackExpectation = expectation(description: "Closure called")
        let completionHandler: AssetDownloadItemCompletionHandler = { result in
            switch result {
            case .success(let data):
                XCTAssertEqual(data, expectedData)
            default:
                XCTFail()
            }
            callbackExpectation.fulfill()
        }

        item.coalesce(completionHandler)
        
        item.completionHandler?(Result<Data>.success(expectedData))
        
        waitForExpectations(timeout: 2) { (error) in
        }
    }
    
    // MARK: Equality
    
    func test_equality_true() {
        let urlA = URL(string: "http://test.com")!
        let urlB = URL(string: "http://test.com")!
        
        let taskA = URLSessionDownloadTaskSpy()
        taskA.currentRequestToBeReturned = URLRequest(url: urlA)
        
        let taskB = URLSessionDownloadTaskSpy()
        taskB.currentRequestToBeReturned = URLRequest(url: urlB)
        
        let itemA = AssetDownloadItem(task: taskA)
        let itemB = AssetDownloadItem(task: taskB)
        
        XCTAssertEqual(itemA, itemB)
    }
    
    func test_equality_false() {
        let urlA = URL(string: "http://testA.com")!
        let urlB = URL(string: "http://testB.com")!
        
        let taskA = URLSessionDownloadTaskSpy()
        taskA.currentRequestToBeReturned = URLRequest(url: urlA)
        
        let taskB = URLSessionDownloadTaskSpy()
        taskB.currentRequestToBeReturned = URLRequest(url: urlB)
        
        let itemA = AssetDownloadItem(task: taskA)
        let itemB = AssetDownloadItem(task: taskB)
        
        XCTAssertNotEqual(itemA, itemB)
    }
}

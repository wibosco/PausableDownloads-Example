//
//  AssetDownloadItemTests.swift
//  UnequalDownloads-ExampleTests
//
//  Created by William Boles on 28/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import XCTest

@testable import UnequalDownloads_Example

class AssetDownloadItemTests: XCTestCase {
    
//    var downloadTask: MockURLSessionDownloadTask!
//
//    // MARK: - Lifecycle
//
//    override func setUp() {
//        super.setUp()
//
//        downloadTask = MockURLSessionDownloadTask()
//    }
//
//    override func tearDown() {
//        downloadTask = nil
//
//        super.tearDown()
//    }
//
//    // MARK: - Tests
//
//    // MARK: Pause
//
//    func test_pause_taskSuspended() {
//        let suspendExpectation = expectation(description: "suspendExpectation")
//        downloadTask.suspendClosure = {
//            suspendExpectation.fulfill()
//        }
//
//        let item = AssetDownloadItem(task: downloadTask)
//        item.pause()
//
//        waitForExpectations(timeout: 3, handler: nil)
//    }
//
//    func test_pause_state() {
//        let item = AssetDownloadItem(task: downloadTask)
//        item.pause()
//
//        XCTAssertEqual(item.status, Status.waiting)
//    }
//
//    func test_pause_immediateDownloadSetToFalse() {
//        let item = AssetDownloadItem(task: downloadTask)
//        item.immediateDownload = true
//        item.pause()
//
//        XCTAssertFalse(item.immediateDownload)
//    }
//
//    // MARK: Resume
//
//    func test_resume_taskResumed() {
//        let resumeExpectation = expectation(description: "resumeExpectation")
//        downloadTask.resumeClosure = {
//            resumeExpectation.fulfill()
//        }
//
//        let item = AssetDownloadItem(task: downloadTask)
//        item.resume()
//
//        waitForExpectations(timeout: 3, handler: nil)
//    }
//
//    func test_resume_state() {
//        let item = AssetDownloadItem(task: downloadTask)
//        item.resume()
//
//        XCTAssertEqual(item.status, Status.downloading)
//    }
//
//    func test_resume_immediateDownloadStaysTrue() {
//        let item = AssetDownloadItem(task: downloadTask)
//        item.immediateDownload = true
//        item.resume()
//
//        XCTAssertTrue(item.immediateDownload)
//    }
//
//    func test_resume_immediateDownloadStaysFalse() {
//        let item = AssetDownloadItem(task: downloadTask)
//        item.immediateDownload = false
//        item.resume()
//
//        XCTAssertFalse(item.immediateDownload)
//    }
//
//    // MARK: SoftCancel
//
//    func test_softCancel_taskSuspend() {
//        let suspendExpectation = expectation(description: "suspendExpectation")
//        downloadTask.suspendClosure = {
//            suspendExpectation.fulfill()
//        }
//
//        let item = AssetDownloadItem(task: downloadTask)
//        item.softCancel()
//
//        waitForExpectations(timeout: 3, handler: nil)
//    }
//
//    func test_softCancel_state() {
//        let item = AssetDownloadItem(task: downloadTask)
//        item.softCancel()
//
//        XCTAssertEqual(item.status, Status.suspended)
//    }
//
//    func test_softCancel_immediateDownloadSetToFalse() {
//        let item = AssetDownloadItem(task: downloadTask)
//        item.immediateDownload = true
//        item.softCancel()
//
//        XCTAssertFalse(item.immediateDownload)
//    }
//
//    // MARK: HardCancel
//
//    func test_hardCancel_taskCancelled() {
//        let cancelExpectation = expectation(description: "cancelExpectation")
//        downloadTask.cancelClosure = {
//            cancelExpectation.fulfill()
//        }
//
//        let item = AssetDownloadItem(task: downloadTask)
//        item.hardCancel()
//
//        waitForExpectations(timeout: 3, handler: nil)
//    }
//
//    func test_hardCancel_state() {
//        let item = AssetDownloadItem(task: downloadTask)
//        item.hardCancel()
//
//        XCTAssertEqual(item.status, Status.cancelled)
//    }
//
//    func test_hardCancel_immediateDownloadSetToFalse() {
//        let item = AssetDownloadItem(task: downloadTask)
//        item.immediateDownload = true
//        item.hardCancel()
//
//        XCTAssertFalse(item.immediateDownload)
//    }
//
//    // MARK: URL
//
//    func test_url_matches() {
//        let url = URL(string: "http://test.com")!
//        let request = URLRequest(url: url)
//        downloadTask.currentRequest = request
//
//        let item = AssetDownloadItem(task: downloadTask)
//
//        XCTAssertEqual(url, item.url)
//    }
//
//    // MARK: Coalesce
//
//    func test_coalesce_mutlipleSuccessCallbacksTriggered() {
//        let expectedData = "this is a test".data(using: .utf8)!
//
//        let itemA = AssetDownloadItem(task: downloadTask)
//
//        let expectationA = expectation(description: "Closure called")
//        itemA.completionHandler = { result in
//            switch result {
//            case .success(let data):
//                XCTAssertEqual(data, expectedData)
//            default:
//                XCTFail()
//            }
//            expectationA.fulfill()
//        }
//
//        let itemB = AssetDownloadItem(task: downloadTask)
//
//        let expectationB = expectation(description: "Closure called")
//        itemB.completionHandler = { result in
//            switch result {
//            case .success(let data):
//                XCTAssertEqual(data, expectedData)
//            default:
//                XCTFail()
//            }
//            expectationB.fulfill()
//        }
//
//        itemA.coalesce(itemB)
//
//        itemA.completionHandler?(Result<Data, Error>.success(expectedData))
//
//        waitForExpectations(timeout: 3, handler: nil)
//    }
//
//    func test_coalesce_mutlipleFailureCallbacksTriggered() {
//        let itemA = AssetDownloadItem(task: downloadTask)
//
//        let expectationA = expectation(description: "Closure called")
//        itemA.completionHandler = { result in
//            switch result {
//            case .failure(_):
//                break
//            default:
//                XCTFail()
//            }
//            expectationA.fulfill()
//        }
//
//        let itemB = AssetDownloadItem(task: downloadTask)
//
//        let expectationB = expectation(description: "Closure called")
//        itemB.completionHandler = { result in
//            switch result {
//            case .failure(_):
//                break
//            default:
//                XCTFail()
//            }
//            expectationB.fulfill()
//        }
//
//        itemA.coalesce(itemB)
//
//        itemA.completionHandler?(Result<Data, Error>.failure(APIError.invalidData))
//
//        waitForExpectations(timeout: 3, handler: nil)
//    }
//
//    func test_coalesce_additionalCallbackTriggeredWhenNoInitialOneExists() {
//        let expectedData = "this is a test".data(using: .utf8)!
//
//        let itemA = AssetDownloadItem(task: downloadTask)
//
//        let itemB = AssetDownloadItem(task: downloadTask)
//
//        let callbackExpectation = expectation(description: "Closure called")
//        itemB.completionHandler = { result in
//            switch result {
//            case .success(let data):
//                XCTAssertEqual(data, expectedData)
//            default:
//                XCTFail()
//            }
//            callbackExpectation.fulfill()
//        }
//
//        itemA.coalesce(itemB)
//
//        itemA.completionHandler?(Result<Data, Error>.success(expectedData))
//
//        waitForExpectations(timeout: 3, handler: nil)
//    }
//
//    // MARK: Equality
//
//    func test_equality_true() {
//        let urlA = URL(string: "http://test.com")!
//        let urlB = URL(string: "http://test.com")!
//
//        let taskA = MockURLSessionDownloadTask()
//        taskA.currentRequest = URLRequest(url: urlA)
//
//        let taskB = MockURLSessionDownloadTask()
//        taskB.currentRequest = URLRequest(url: urlB)
//
//        let itemA = AssetDownloadItem(task: taskA)
//        let itemB = AssetDownloadItem(task: taskB)
//
//        XCTAssertEqual(itemA, itemB)
//    }
//
//    func test_equality_false() {
//        let urlA = URL(string: "http://testA.com")!
//        let urlB = URL(string: "http://testB.com")!
//
//        let taskA = MockURLSessionDownloadTask()
//        taskA.currentRequest = URLRequest(url: urlA)
//
//        let taskB = MockURLSessionDownloadTask()
//        taskB.currentRequest = URLRequest(url: urlB)
//
//        let itemA = AssetDownloadItem(task: taskA)
//        let itemB = AssetDownloadItem(task: taskB)
//
//        XCTAssertNotEqual(itemA, itemB)
//    }
}

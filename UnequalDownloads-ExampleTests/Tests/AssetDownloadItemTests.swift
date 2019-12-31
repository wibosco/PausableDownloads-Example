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
    
    var sut: AssetDownloadItem!
    
    var session: MockURLSession!
    let url = URL(string: "http://test.com/example")!
    
    var downloadTask: MockURLSessionDownloadTask!

    // MARK: - Lifecycle

    override func setUp() {
        super.setUp()

        downloadTask = MockURLSessionDownloadTask()
        session = MockURLSession()
        session.downloadTask = downloadTask
        
        sut = AssetDownloadItem(session: session, url: url, immediateDownload: false)
    }

    override func tearDown() {
        downloadTask = nil
        session = nil
        
        sut = nil

        super.tearDown()
    }

    // MARK: - Tests

    // MARK: Resume

    func test_resume_noResumeData_taskResumed() {
        let resumeExpectation = expectation(description: "resumeExpectation")
        downloadTask.resumeClosure = {
            resumeExpectation.fulfill()
        }
        
        let downloadTaskExpectation = expectation(description: "downloadTaskExpectation")
        session.downloadTaskClosure = { (url, _) in
            XCTAssertEqual(url, self.url)
            
            downloadTaskExpectation.fulfill()
        }

        sut.resume()

        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_resume_resumeData_taskResumed() {
        let data = "resume data".data(using: .utf8)
        
        let cancelExpectation = expectation(description: "cancelExpectation")
        downloadTask.cancelByProducingResumeDataClosure = { completion in
            completion(data)
            
            cancelExpectation.fulfill()
        }

        sut.resume()
        sut.pause()

        waitForExpectations(timeout: 3, handler: nil)
        
        let resumeExpectation = expectation(description: "resumeExpectation")
        downloadTask.resumeClosure = {
            resumeExpectation.fulfill()
        }
        
        let downloadTaskExpectation = expectation(description: "downloadTaskExpectation")
        session.downloadTaskWithResumeDataClosure = { (resumeData, _) in
            XCTAssertEqual(resumeData, data)
            
            downloadTaskExpectation.fulfill()
        }
        
        sut.resume()
        
        waitForExpectations(timeout: 3, handler: nil)
    }

    func test_resume_state() {
        sut.resume()

        XCTAssertEqual(sut.status, Status.downloading)
    }

    func test_resume_immediateDownloadStaysTrue() {
        sut.immediateDownload = true
        sut.resume()

        XCTAssertTrue(sut.immediateDownload)
    }

    func test_resume_immediateDownloadStaysFalse() {
        sut.immediateDownload = false
        sut.resume()

        XCTAssertFalse(sut.immediateDownload)
    }
    
    func test_resume_downloadCompletes_success_triggerCompletion() {
        let assetURL = Bundle(for: type(of: self)).url(forResource: "square", withExtension: "pdf")!

        let downloadTaskExpectation = expectation(description: "downloadTaskExpectation")
        var completion: ((URL?, URLResponse?, Error?) -> ())?
        session.downloadTaskClosure = { (url, completionHandler) in
            completion = completionHandler
           
            downloadTaskExpectation.fulfill()
        }

        sut.resume()

        waitForExpectations(timeout: 3, handler: nil)

        let completionHandlerExpectation = expectation(description: "completionHandlerExpectation")
        sut.completionHandler = { _, result in
            guard case let .success(data) = result else {
               XCTFail("Expecting success case")
               return
            }
            
            let expectedData = try? Data(contentsOf: assetURL)
            
            XCTAssertEqual(data, expectedData)
            
            completionHandlerExpectation.fulfill()
        }

        let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)

        completion?(assetURL, response, nil)

        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_resume_downloadCompletes_failure_triggerCompletion() {
        let downloadTaskExpectation = expectation(description: "downloadTaskExpectation")
        var completion: ((URL?, URLResponse?, Error?) -> ())?
        session.downloadTaskClosure = { (url, completionHandler) in
            completion = completionHandler
            
            downloadTaskExpectation.fulfill()
        }
        
        sut.resume()
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let completionHandlerExpectation = expectation(description: "completionHandlerExpectation")
        sut.completionHandler = { _, result in
            guard case let .failure(error) = result else {
                XCTFail("Expecting failure case")
                return
            }
            
            guard let networkingError = error as? NetworkingError,
                case let .retrieval(underlyingError) = networkingError else {
                XCTFail("Expecting retrieval networking error")
                return
            }
            
            XCTAssertEqual(underlyingError as! TestError, TestError.test)
            
            completionHandlerExpectation.fulfill()
        }

        let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        
        completion?(nil, response, TestError.test)
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_resume_downloadCompletes_cancelled_doNotTriggerCompletion() {
        let downloadTaskExpectation = expectation(description: "downloadTaskExpectation")
        var completion: ((URL?, URLResponse?, Error?) -> ())?
        session.downloadTaskClosure = { (url, completionHandler) in
            completion = completionHandler
            
            downloadTaskExpectation.fulfill()
        }
        
        sut.resume()
        sut.pause()
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let completionHandlerExpectation = expectation(description: "completionHandlerExpectation")
        completionHandlerExpectation.isInverted = true
        sut.completionHandler = { _, result in
            completionHandlerExpectation.fulfill()
        }

        let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        let error = NSError(domain: "Test", code: NSURLErrorCancelled, userInfo: nil)
        
        completion?(nil, response, error)
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    // MARK: Pause

    func test_pause_taskCancelled() {
        let cancelExpectation = expectation(description: "cancelExpectation")
        downloadTask.cancelByProducingResumeDataClosure = { _ in
            cancelExpectation.fulfill()
        }
        
        sut.resume()
        sut.pause()

        waitForExpectations(timeout: 3, handler: nil)
    }

    func test_pause_state() {
        sut.pause()

        XCTAssertEqual(sut.status, Status.paused)
    }

    func test_pause_immediateDownloadSetToFalse() {
        sut.immediateDownload = true
        sut.pause()

        XCTAssertFalse(sut.immediateDownload)
    }

    // MARK: Cancel

    func test_cancel_taskCancelled() {
        let cancelExpectation = expectation(description: "cancelExpectation")
        downloadTask.cancelClosure = {
            cancelExpectation.fulfill()
        }

        sut.resume()
        sut.cancel()

        waitForExpectations(timeout: 3, handler: nil)
    }

    func test_cancel_state() {
        sut.cancel()

        XCTAssertEqual(sut.status, Status.cancelled)
    }

    func test_cancel_immediateDownloadSetToFalse() {
        sut.immediateDownload = true
        sut.cancel()

        XCTAssertFalse(sut.immediateDownload)
    }
    
    // MARK: Done
    
    func test_done_state() {
        sut.done()

        XCTAssertEqual(sut.status, Status.done)
    }

    // MARK: Coalesce

    func test_coalesce_mutlipleSuccessCallbacksTriggered() {
        let expectedData = "this is a test".data(using: .utf8)!

        let itemA = AssetDownloadItem(session: session, url: url, immediateDownload: false)

        let expectationA = expectation(description: "Closure called")
        itemA.completionHandler = { _, result in
            guard case let .success(data) = result else {
                XCTFail("Expecting success case")
                return
            }
            
            XCTAssertEqual(data, expectedData)
            expectationA.fulfill()
        }

        let itemB = AssetDownloadItem(session: session, url: url, immediateDownload: false)

        let expectationB = expectation(description: "Closure called")
        itemB.completionHandler = { _, result in
            guard case let .success(data) = result else {
                XCTFail("Expecting success case")
                return
            }
            
            XCTAssertEqual(data, expectedData)
            
            expectationB.fulfill()
        }

        itemA.coalesce(itemB)
        
        let result = Result<Data, Error>.success(expectedData)
        itemA.completionHandler?(itemA, result)

        waitForExpectations(timeout: 3, handler: nil)
    }

    func test_coalesce_mutlipleFailureCallbacksTriggered() {
        let itemA = AssetDownloadItem(session: session, url: url, immediateDownload: false)

        let expectationA = expectation(description: "Closure called")
        itemA.completionHandler = { _, result in
            guard case .failure(_) = result else {
                XCTFail("Expecting failure case")
                return
            }
            expectationA.fulfill()
        }

        let itemB = AssetDownloadItem(session: session, url: url, immediateDownload: false)

        let expectationB = expectation(description: "Closure called")
        itemB.completionHandler = { _, result in
            guard case .failure(_) = result else {
                XCTFail("Expecting failure case")
                return
            }
            expectationB.fulfill()
        }

        itemA.coalesce(itemB)

        let result = Result<Data, Error>.failure(NetworkingError.unknown)
        itemA.completionHandler?(itemA, result)

        waitForExpectations(timeout: 3, handler: nil)
    }

    func test_coalesce_additionalCallbackTriggeredWhenNoInitialOneExists() {
        let expectedData = "this is a test".data(using: .utf8)!

        let itemA = AssetDownloadItem(session: session, url: url, immediateDownload: false)

        let itemB = AssetDownloadItem(session: session, url: url, immediateDownload: false)

        let callbackExpectation = expectation(description: "Closure called")
        itemB.completionHandler = { _, result in
            guard case let .success(data) = result else {
                XCTFail("Expecting success case")
                return
            }
            
            XCTAssertEqual(data, expectedData)
            
            callbackExpectation.fulfill()
        }

        itemA.coalesce(itemB)

        let result = Result<Data, Error>.success(expectedData)
        itemA.completionHandler?(itemA, result)

        waitForExpectations(timeout: 3, handler: nil)
    }
}

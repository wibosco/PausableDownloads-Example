//
//  AssetDownloadsSessionTests.swift
//  UnequalDownloads-ExampleTests
//
//  Created by William Boles on 15/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import XCTest

@testable import UnequalDownloads_Example

class AssetDownloadsSessionTests: XCTestCase {
    
    var sut: AssetDownloadsSession!
    
    var sessionFactory: MockURLSessionFactory!
    var session: MockURLSession!
    var notificationCenter: MockNotificationCenter!
//    var assetDownloadItemFactory: MockAssetDownloadItemFactory!
    
    let url = URL(string: "http://test.com/example")!
    
    // MARK: - Lifecycle
    
    override func setUp() {
        super.setUp()
        
        sessionFactory = MockURLSessionFactory()
        session = MockURLSession()
        sessionFactory.defaultSession = session
        notificationCenter = MockNotificationCenter()
//        assetDownloadItemFactory = MockAssetDownloadItemFactory()
        
        sut = AssetDownloadsSession(urlSessionFactory: sessionFactory, notificationCenter: notificationCenter)
    }

    override func tearDown() {
        notificationCenter = nil
        sessionFactory = nil
        session = nil
//        assetDownloadItemFactory = nil
        
        sut = nil
        
        super.tearDown()
    }
    
    // MARK: - Tests
    
    // MARK: Notification
    
    func test_init_notificationRegistration() {
        let notificationCenter = MockNotificationCenter()
        let addObserverExpectation = expectation(description: "addObserverExpectation")
        notificationCenter.addObserverClosure = { (name, object, queue, block) in
            XCTAssertEqual(name, UIApplication.didReceiveMemoryWarningNotification)
            
            addObserverExpectation.fulfill()
        }
        
        _ = AssetDownloadsSession(notificationCenter: notificationCenter)
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_init_sendNotification_cancelPausedDownloads() {
        let notificationCenter = MockNotificationCenter()
        
        var notificationBlock: ((Notification) -> Void)?
        let addObserverExpectation = expectation(description: "addObserverExpectation")
        notificationCenter.addObserverClosure = { (name, object, queue, block) in
            notificationBlock = block
            
            addObserverExpectation.fulfill()
        }
        
        let sessionFactory = MockURLSessionFactory()
        let session = MockURLSession()
        sessionFactory.defaultSession = session
        
        let sut = AssetDownloadsSession(urlSessionFactory: sessionFactory, notificationCenter: notificationCenter)
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let downloadTask = MockURLSessionDownloadTask()
        session.downloadTask = downloadTask
        
        let downloadTaskExpectation = expectation(description: "downloadTaskExpectation")
        session.downloadTaskClosure = { (url, completion) in
            downloadTaskExpectation.fulfill()
        }
        
        sut.scheduleDownload(url: url) { _ in }
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let cancelByProducingResumeDataExpectation = expectation(description: "cancelByProducingResumeDataExpectation")
        downloadTask.cancelByProducingResumeDataClosure = { (completion) in
            cancelByProducingResumeDataExpectation.fulfill()
        }
        
        sut.cancelDownload(url: url)
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let cancelExpectation = expectation(description: "cancelExpectation")
        downloadTask.cancelClosure = {
            cancelExpectation.fulfill()
        }
        
        let notification = Notification(name: UIApplication.didReceiveMemoryWarningNotification)
        notificationBlock?(notification)
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    // MARK: Schedule
    
    func test_scheduleDownload_startsDownload() {
        let downloadTask = MockURLSessionDownloadTask()
        let resumeExpectation = expectation(description: "resumeExpectation")
        downloadTask.resumeClosure = {
            resumeExpectation.fulfill()
        }
        
        session.downloadTask = downloadTask
        
        let downloadTaskExpectation = expectation(description: "downloadTaskExpectation")
        session.downloadTaskClosure = { (url, completion) in
            XCTAssertEqual(url, self.url)
            
            downloadTaskExpectation.fulfill()
        }
        
        sut.scheduleDownload(url: url) { _ in }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_scheduleDownload_mulitple_startsAllDownloads() {
        let downloadTask = MockURLSessionDownloadTask()
        let resumeExpectation = expectation(description: "resumeExpectation")
        resumeExpectation.expectedFulfillmentCount = 2
        downloadTask.resumeClosure = {
            resumeExpectation.fulfill()
        }
        
        session.downloadTask = downloadTask
        
        let urlA = URL(string: "http://example.com/resourceA")!
        let urlB = URL(string: "http://example.com/resourceB")!
        
        sut.scheduleDownload(url: urlA) { _ in }
        sut.scheduleDownload(url: urlB) { _ in }

        waitForExpectations(timeout: 3, handler: nil)
    }

    func test_scheduleDownload_multiple_coalesceDownloads() {
        let downloadTask = MockURLSessionDownloadTask()
        let resumeExpectation = expectation(description: "resumeExpectation")
        downloadTask.resumeClosure = {
            resumeExpectation.fulfill()
        }
        
        session.downloadTask = downloadTask
        
        var downloadTaskCompletion: ((URL?, URLResponse?, Error?) -> Void)?
        let downloadTaskExpectation = expectation(description: "downloadTaskExpectation")
        session.downloadTaskClosure = { (url, completion) in
            downloadTaskCompletion = completion
            
            downloadTaskExpectation.fulfill()
        }
        
        let firstCompletionExpectation = expectation(description: "firstCompletionExpectation")
        sut.scheduleDownload(url: url) { (_) in
            firstCompletionExpectation.fulfill()
        }
        
        let secondCompletionExpectation = expectation(description: "secondCompletionExpectation")
        sut.scheduleDownload(url: url) { (_) in
            secondCompletionExpectation.fulfill()
        }
        
        downloadTaskCompletion?(nil, nil, nil)
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_scheduleDownload_cancelledDownload_reviveCancelledDownload() {
        let downloadTask = MockURLSessionDownloadTask()
        let downloadTaskPauseExpectation = expectation(description: "downloadTaskPauseExpectation")
        downloadTask.cancelByProducingResumeDataClosure = { (completion) in
            downloadTaskPauseExpectation.fulfill()
        }
        
        session.downloadTask = downloadTask

        sut.scheduleDownload(url: url) { _ in }
        sut.cancelDownload(url: url)
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let resumeExpectation = expectation(description: "resumeExpectation")
        downloadTask.resumeClosure = {
            resumeExpectation.fulfill()
        }
        
        sut.scheduleDownload(url: url) { _ in }
        
        waitForExpectations(timeout: 3, handler: nil)
    }

    func test_scheduleDownload_completeDownload_removeFromCachedDownloadAssetItems_requestingSameURLResultsInNewDownload() {
        var downloadTaskCompletion: ((URL?, URLResponse?, Error?) -> Void)?
        let firstDownloadTaskExpectation = expectation(description: "firstDownloadTaskExpectation")
        session.downloadTaskClosure = { (_, completion) in
            downloadTaskCompletion = completion
            
            firstDownloadTaskExpectation.fulfill()
        }
        
        sut.scheduleDownload(url: url) { (_) in }
        
        downloadTaskCompletion?(nil, nil, nil)
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let secondDownloadTaskExpectation = expectation(description: "secondDownloadTaskExpectation")
        session.downloadTaskClosure = { (_, _) in
            secondDownloadTaskExpectation.fulfill()
        }
        
        sut.scheduleDownload(url: url) { (_) in }
        
        waitForExpectations(timeout: 3, handler: nil)
    }

    func test_scheduleDownload_completeDownload_triggerCompletionClosure() {
        var downloadTaskCompletion: ((URL?, URLResponse?, Error?) -> Void)?
        let firstDownloadTaskExpectation = expectation(description: "firstDownloadTaskExpectation")
        session.downloadTaskClosure = { (_, completion) in
            downloadTaskCompletion = completion
          
            firstDownloadTaskExpectation.fulfill()
        }

        let completionExpectation = expectation(description: "completionExpectation")
        sut.scheduleDownload(url: url) { (_) in
            completionExpectation.fulfill()
        }

        downloadTaskCompletion?(nil, nil, nil)

        waitForExpectations(timeout: 3, handler: nil)
    }

    // MARK: Cancel

    func test_cancelDownload_cancelByProducingResumeData() {
        let downloadTask = MockURLSessionDownloadTask()
        let downloadTaskPauseExpectation = expectation(description: "downloadTaskPauseExpectation")
        downloadTask.cancelByProducingResumeDataClosure = { (completion) in
           downloadTaskPauseExpectation.fulfill()
        }

        session.downloadTask = downloadTask
        
        sut.scheduleDownload(url: url) { _ in }
        sut.cancelDownload(url: url)

        waitForExpectations(timeout: 3, handler: nil)
    }
}

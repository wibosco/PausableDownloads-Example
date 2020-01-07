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
    
    func test_init_sendNotification_cancelHibernatingDownloads() {
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
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        
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
    
    func test_scheduleDownload_nonImmediate_startsDownload() {
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
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_scheduleDownload_mulitple_nonImmediate_startsAllDownloads() {
        let downloadTask = MockURLSessionDownloadTask()
        let resumeExpectation = expectation(description: "resumeExpectation")
        resumeExpectation.expectedFulfillmentCount = 2
        downloadTask.resumeClosure = {
            resumeExpectation.fulfill()
        }
        
        session.downloadTask = downloadTask
        
        let urlA = URL(string: "http://example.com/resourceA")!
        let urlB = URL(string: "http://example.com/resourceB")!
        
        sut.scheduleDownload(url: urlA, immediateDownload: false) { _ in }
        sut.scheduleDownload(url: urlB, immediateDownload: false) { _ in }

        waitForExpectations(timeout: 3, handler: nil)
    }

    func test_scheduleDownload_whenImmediateDownloadIsScheduledPauseOtherDownloads_startImmediateDownload() {
        let nonImmediateDownloadTask = MockURLSessionDownloadTask()
        let nonImmediateDownloadTaskCancelExpectation = expectation(description: "nonImmediateDownloadTaskCancelExpectation")
        nonImmediateDownloadTask.cancelByProducingResumeDataClosure = { (completion) in
            nonImmediateDownloadTaskCancelExpectation.fulfill()
        }
        
        session.downloadTask = nonImmediateDownloadTask

        let nonImmediateURL = URL(string: "http://example.com/resourceA")!
        sut.scheduleDownload(url: nonImmediateURL, immediateDownload: false) { _ in }
        
        let immediateDownloadTask = MockURLSessionDownloadTask()
        let immediateDownloadTaskResumeExpectation = expectation(description: "immediateDownloadTaskResumeExpectation")
        immediateDownloadTask.resumeClosure = {
            immediateDownloadTaskResumeExpectation.fulfill()
        }
        
        session.downloadTask = immediateDownloadTask

        let immediateURL = URL(string: "http://example.com/resourceB")!
        sut.scheduleDownload(url: immediateURL, immediateDownload: true) { _ in }

        wait(for: [nonImmediateDownloadTaskCancelExpectation, immediateDownloadTaskResumeExpectation], timeout: 3, enforceOrder: true)
    }

    func test_scheduleDownload_whenImmediateDownloadIsActiveSubsequentNonImmediateDownloadAreNotStarted() {
        let immediateDownloadTask = MockURLSessionDownloadTask()
        
        session.downloadTask = immediateDownloadTask

        let immediateURL = URL(string: "http://example.com/resourceB")!
        sut.scheduleDownload(url: immediateURL, immediateDownload: true) { _ in }
        
        let nonImmediateDownloadTask = MockURLSessionDownloadTask()
        let nonImmediateDownloadTaskResumeExpectation = expectation(description: "nonImmediateDownloadTaskResumeExpectation")
        nonImmediateDownloadTaskResumeExpectation.isInverted = true
        nonImmediateDownloadTask.resumeClosure = {
            nonImmediateDownloadTaskResumeExpectation.fulfill()
        }
        
        session.downloadTask = nonImmediateDownloadTask

        let nonImmediateURL = URL(string: "http://example.com/resourceA")!
        sut.scheduleDownload(url: nonImmediateURL, immediateDownload: false) { _ in }

        waitForExpectations(timeout: 3, handler: nil)
    }

    func test_scheduleDownload_immediateDownloadIsActive_scheduleAnotherImmediateDownload_pausesFirstDownload() {
        let immediateDownloadTaskA = MockURLSessionDownloadTask()
        let immediateDownloadTaskPauseExpectation = expectation(description: "immediateDownloadTaskPauseExpectation")
        immediateDownloadTaskA.cancelByProducingResumeDataClosure = { (completion) in
           immediateDownloadTaskPauseExpectation.fulfill()
        }

        session.downloadTask = immediateDownloadTaskA

        let immediateURLA = URL(string: "http://example.com/resourceA")!
        sut.scheduleDownload(url: immediateURLA, immediateDownload: true) { _ in }

        let immediateDownloadTaskB = MockURLSessionDownloadTask()
        let immediateDownloadTaskResumeExpectation = expectation(description: "immediateDownloadTaskResumeExpectation")
        immediateDownloadTaskB.resumeClosure = {
           immediateDownloadTaskResumeExpectation.fulfill()
        }

        session.downloadTask = immediateDownloadTaskB

        let immediateURLB = URL(string: "http://example.com/resourceB")!
        sut.scheduleDownload(url: immediateURLB, immediateDownload: true) { _ in }

        wait(for: [immediateDownloadTaskPauseExpectation, immediateDownloadTaskResumeExpectation], timeout: 3, enforceOrder: true)
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
        sut.scheduleDownload(url: url, immediateDownload: false) { (_) in
            firstCompletionExpectation.fulfill()
        }
        
        let secondCompletionExpectation = expectation(description: "secondCompletionExpectation")
        sut.scheduleDownload(url: url, immediateDownload: false) { (_) in
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

        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        sut.cancelDownload(url: url)
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let resumeExpectation = expectation(description: "resumeExpectation")
        downloadTask.resumeClosure = {
            resumeExpectation.fulfill()
        }
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        
        waitForExpectations(timeout: 3, handler: nil)
    }

    func test_scheduleDownload_completeDownload_removeFromCachedDownloadAssetItems_requestingSameURLResultsInNewDownload() {
        var downloadTaskCompletion: ((URL?, URLResponse?, Error?) -> Void)?
        let firstDownloadTaskExpectation = expectation(description: "firstDownloadTaskExpectation")
        session.downloadTaskClosure = { (_, completion) in
            downloadTaskCompletion = completion
            
            firstDownloadTaskExpectation.fulfill()
        }
        
        sut.scheduleDownload(url: url, immediateDownload: false) { (_) in }
        
        downloadTaskCompletion?(nil, nil, nil)
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let secondDownloadTaskExpectation = expectation(description: "secondDownloadTaskExpectation")
        session.downloadTaskClosure = { (_, _) in
            secondDownloadTaskExpectation.fulfill()
        }
        
        sut.scheduleDownload(url: url, immediateDownload: false) { (_) in }
        
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
        sut.scheduleDownload(url: url, immediateDownload: false) { (_) in
            completionExpectation.fulfill()
        }

        downloadTaskCompletion?(nil, nil, nil)

        waitForExpectations(timeout: 3, handler: nil)
    }

    // MARK: Cancel

    func test_cancelDownload_download() {
        let downloadTask = MockURLSessionDownloadTask()
        let downloadTaskPauseExpectation = expectation(description: "downloadTaskPauseExpectation")
        downloadTask.cancelByProducingResumeDataClosure = { (completion) in
           downloadTaskPauseExpectation.fulfill()
        }

        session.downloadTask = downloadTask

        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        sut.cancelDownload(url: url)

        waitForExpectations(timeout: 3, handler: nil)
    }
}

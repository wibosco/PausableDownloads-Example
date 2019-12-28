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
    var assetDownloadItemFactory: MockAssetDownloadItemFactory!
    
    let url = URL(string: "http://test.com/example")!
    
    // MARK: - Lifecycle
    
    override func setUp() {
        super.setUp()
        
        sessionFactory = MockURLSessionFactory()
        session = MockURLSession()
        sessionFactory.defaultSession = session
        notificationCenter = MockNotificationCenter()
        assetDownloadItemFactory = MockAssetDownloadItemFactory()
        
        sut = AssetDownloadsSession(urlSessionFactory: sessionFactory, assetDownloadItemFactory: assetDownloadItemFactory, notificationCenter: notificationCenter)
    }

    override func tearDown() {
        notificationCenter = nil
        sessionFactory = nil
        session = nil
        assetDownloadItemFactory = nil
        
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
    
    // MARK: Schedule
    
    func test_scheduleDownload_nonImmediate_startsDownload() {
        let assetDownloadItemExpectaion = expectation(description: "assetDownloadItemExpectation")
        assetDownloadItemFactory.assetDownloadItemClosure = { (url, _, immediateDownload, _) in
            XCTAssertEqual(url, self.url)
            XCTAssertFalse(immediateDownload)
            
            assetDownloadItemExpectaion.fulfill()
        }
        
        let assetDownloadItem = MockAssetDownloadItem()
        let resumeExpectation = expectation(description: "resumeExpectation")
        assetDownloadItem.resumeClosure = {
            resumeExpectation.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = assetDownloadItem
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_scheduleDownload_mulitple_nonImmediate_startsAllDownloads() {
        let assetDownloadItemA = MockAssetDownloadItem()
        let resumeExpectationA = expectation(description: "resumeAExpectation")
        assetDownloadItemA.resumeClosure = {
            resumeExpectationA.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = assetDownloadItemA
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        
        wait(for: [resumeExpectationA], timeout: 3)
        
        let urlB = URL(string: "http://differenturl.com/example")!
        
        let assetDownloadItemB = MockAssetDownloadItem()
        assetDownloadItemB.url = urlB
        let resumeExpectationB = expectation(description: "resumeBExpectation")
        assetDownloadItemB.resumeClosure = {
            resumeExpectationB.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = assetDownloadItemB
        
        sut.scheduleDownload(url: urlB, immediateDownload: false) { _ in }
        
        wait(for: [resumeExpectationB], timeout: 3)
    }
    
    func test_scheduleDownload_whenImmediateDownloadIsScheduledPauseOtherDownloads_startImmediateDownloads() {
        let nonImmediateAssetDownloadItem = MockAssetDownloadItem()
        let nonImmediatePauseExpectation = expectation(description: "nonImmediatePauseExpectation")
        nonImmediateAssetDownloadItem.pauseClosure = {
            nonImmediatePauseExpectation.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = nonImmediateAssetDownloadItem
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        
        let immediateURL = URL(string: "http://differenturl.com/example")!
        
        let immediateAssetDownloadItem = MockAssetDownloadItem()
        immediateAssetDownloadItem.url = immediateURL
        let immediateResumeExpectation = expectation(description: "immediateResumeExpectation")
        immediateAssetDownloadItem.resumeClosure = {
            immediateResumeExpectation.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = immediateAssetDownloadItem
        
        sut.scheduleDownload(url: immediateURL, immediateDownload: true) { _ in }
        
        wait(for: [nonImmediatePauseExpectation, immediateResumeExpectation], timeout: 3, enforceOrder: true)
    }
    
    func test_scheduleDownload_whenImmediateDownloadIsActiveSubsequentNonImmediateDownloadArePaused() {
        let immediateURL = URL(string: "http://differenturl.com/example")!
        
        let immediateAssetDownloadItem = MockAssetDownloadItem()
        immediateAssetDownloadItem.url = immediateURL
        let immediateResumeExpectation = expectation(description: "immediateResumeExpectation")
        immediateAssetDownloadItem.resumeClosure = {
            immediateResumeExpectation.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = immediateAssetDownloadItem
        
        sut.scheduleDownload(url: immediateURL, immediateDownload: true) { _ in }
        
        let nonImmediateAssetDownloadItem = MockAssetDownloadItem()
        let nonImmediateResumeExpectation = expectation(description: "nonImmediateResumeExpectation")
        nonImmediateResumeExpectation.isInverted = true
        nonImmediateAssetDownloadItem.resumeClosure = {
            nonImmediateResumeExpectation.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = nonImmediateAssetDownloadItem
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_scheduleDownload_immediateDownloadIsActive_scheduleAnotherImmediateDownload_pausesFirstDownload() {
        let immediateURL = URL(string: "http://differenturl.com/example")!
        
        let firstImmediateAssetDownloadItem = MockAssetDownloadItem()
        firstImmediateAssetDownloadItem.url = immediateURL
        let firstImmediatePauseExpectation = expectation(description: "firstImmediatePauseExpectation")
        firstImmediateAssetDownloadItem.pauseClosure = {
            firstImmediatePauseExpectation.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = firstImmediateAssetDownloadItem
        
        sut.scheduleDownload(url: immediateURL, immediateDownload: true) { _ in }
        
        let secondImmediateAssetDownloadItem = MockAssetDownloadItem()
        let secondImmediateResumeExpectation = expectation(description: "secondImmediateResumeExpectation")
        secondImmediateAssetDownloadItem.resumeClosure = {
            secondImmediateResumeExpectation.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = secondImmediateAssetDownloadItem
        
        sut.scheduleDownload(url: url, immediateDownload: true) { _ in }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_scheduleDownload_multiple_coalesceActiveDownload() {
        let firstAssetDownloadItem = MockAssetDownloadItem()
        let secondAssetDownloadItem = MockAssetDownloadItem()
        
        let firstAssetDownloadItemCoalesceExpectation = expectation(description: "firstAssetDownloadItemCoalesceExpectation")
        firstAssetDownloadItem.coalesceClosure = { assetDownloadItem in
            XCTAssertTrue(assetDownloadItem === secondAssetDownloadItem)
            
            firstAssetDownloadItemCoalesceExpectation.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = firstAssetDownloadItem
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        
        let secondAssetDownloadItemResumeExpectation = expectation(description: "secondAssetDownloadItemResumeExpectation")
        secondAssetDownloadItemResumeExpectation.isInverted = true
        secondAssetDownloadItem.resumeClosure = {
            secondAssetDownloadItemResumeExpectation.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = secondAssetDownloadItem
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_scheduleDownload_multiple_coalescePausedDownload() {
        let firstAssetDownloadItem = MockAssetDownloadItem()
        let secondAssetDownloadItem = MockAssetDownloadItem()
        
        let firstAssetDownloadItemCoalesceExpectation = expectation(description: "firstAssetDownloadItemCoalesceExpectation")
        firstAssetDownloadItem.coalesceClosure = { assetDownloadItem in
            firstAssetDownloadItemCoalesceExpectation.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = firstAssetDownloadItem
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        
        let immediateURL = URL(string: "http://differenturl.com/example")!
        
        let immediateAssetDownloadItem = MockAssetDownloadItem()
        immediateAssetDownloadItem.url = immediateURL
        
        assetDownloadItemFactory.assetDownloadItem = immediateAssetDownloadItem
        
        sut.scheduleDownload(url: immediateURL, immediateDownload: true) { _ in }
        
        let secondAssetDownloadItemResumeExpectation = expectation(description: "secondAssetDownloadItemResumeExpectation")
        secondAssetDownloadItemResumeExpectation.isInverted = true
        secondAssetDownloadItem.resumeClosure = {
            secondAssetDownloadItemResumeExpectation.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = secondAssetDownloadItem
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_scheduleDownload_cancelledDownload_reviveCancelledDownload_withCoalescing() {
        let firstAssetDownloadItem = MockAssetDownloadItem()
        firstAssetDownloadItem.url = url
        let secondAssetDownloadItem = MockAssetDownloadItem()
        secondAssetDownloadItem.url = url
        
        let firstAssetDownloadItemPauseExpectation = expectation(description: "firstAssetDownloadItemPauseExpectation")
        firstAssetDownloadItem.pauseClosure = {
            firstAssetDownloadItemPauseExpectation.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = firstAssetDownloadItem
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        
        sut.cancelDownload(url: url)
        
        wait(for: [firstAssetDownloadItemPauseExpectation], timeout: 3)
        
        let firstAssetDownloadItemCoalesceExpectation = expectation(description: "firstAssetDownloadItemCoalesceExpectation")
        firstAssetDownloadItemCoalesceExpectation.isInverted = true
        firstAssetDownloadItem.coalesceClosure = { assetDownloadItem in
            firstAssetDownloadItemCoalesceExpectation.fulfill()
        }
        
        let secondAssetDownloadItemResumeExpectation = expectation(description: "secondAssetDownloadItemResumeExpectation")
        secondAssetDownloadItemResumeExpectation.isInverted = true
        secondAssetDownloadItem.resumeClosure = {
            secondAssetDownloadItemResumeExpectation.fulfill()
        }
        
        let firstAssetDownloadItemResumeExpectation = expectation(description: "firstAssetDownloadItemResumeExpectation")
        firstAssetDownloadItem.resumeClosure = {
            firstAssetDownloadItemResumeExpectation.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = secondAssetDownloadItem
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_scheduleDownload_completeDownload_updateItemAsDone() {
        let assetDownloadItem = MockAssetDownloadItem()
        let doneExpectation = expectation(description: "doneExpectation")
        assetDownloadItem.doneClosure = {
            doneExpectation.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = assetDownloadItem
        let assetDownloadItemExpectation = expectation(description: "assetDownloadItemExpectation")
        var assetDownloadItemCompletionClosure: AssetDownloadItemCompletionHandler?
        assetDownloadItemFactory.assetDownloadItemClosure = { (url, session, immediateDownload, completionHandler) in
            assetDownloadItemCompletionClosure = completionHandler

            assetDownloadItemExpectation.fulfill()
        }
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
    
        wait(for: [assetDownloadItemExpectation], timeout: 3)
        
        let data = "success data".data(using: .utf8)!
        let result = Result<Data, Error>.success(data)
        assetDownloadItemCompletionClosure?(assetDownloadItem, result)

        wait(for: [doneExpectation], timeout: 3)
    }
    
    func test_scheduleDownload_completeDownload_triggerCompletionClosure() {
        let assetDownloadItem = MockAssetDownloadItem()
        
        assetDownloadItemFactory.assetDownloadItem = assetDownloadItem
        let assetDownloadItemExpectation = expectation(description: "assetDownloadItemExpectation")
        var assetDownloadItemCompletionClosure: AssetDownloadItemCompletionHandler?
        assetDownloadItemFactory.assetDownloadItemClosure = { (url, session, immediateDownload, completionHandler) in
            assetDownloadItemCompletionClosure = completionHandler
            
            assetDownloadItemExpectation.fulfill()
        }
        
        let completionExpectation = expectation(description: "completionExpectation")
        let data = "success data".data(using: .utf8)!
        
        sut.scheduleDownload(url: url, immediateDownload: false) { returnedResult in
            guard case let .success(returnedData) = returnedResult else {
                XCTFail("Unexpected case returned")
                return
            }
            
            XCTAssertEqual(returnedData, data)
            
            completionExpectation.fulfill()
        }
        
        wait(for: [assetDownloadItemExpectation], timeout: 3)
        
        let result = Result<Data, Error>.success(data)
        assetDownloadItemCompletionClosure?(assetDownloadItem, result)
    
        wait(for: [completionExpectation], timeout: 3)
    }
    
    func test_scheduleDownload_completeDownload_removesDownload() {
        let assetDownloadItem = MockAssetDownloadItem()
        
        assetDownloadItemFactory.assetDownloadItem = assetDownloadItem
        var assetDownloadItemExpectation: XCTestExpectation? = expectation(description: "assetDownloadItemExpectation")
        var assetDownloadItemCompletionClosure: AssetDownloadItemCompletionHandler?
        assetDownloadItemFactory.assetDownloadItemClosure = { (url, session, immediateDownload, completionHandler) in
            assetDownloadItemCompletionClosure = completionHandler
            
            assetDownloadItemExpectation?.fulfill()
        }
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
    
        waitForExpectations(timeout: 3, handler: nil)
        
        assetDownloadItemExpectation = nil
        
        let doneExpectation = expectation(description: "doneExpectation")
        assetDownloadItem.doneClosure = {
            doneExpectation.fulfill()
        }
        
        let result = Result<Data, Error>.success("success data".data(using: .utf8)!)
        assetDownloadItemCompletionClosure?(assetDownloadItem, result)
        
        let coalesceExpectation = expectation(description: "coalesceExpectation")
        coalesceExpectation.isInverted = true
        assetDownloadItem.coalesceClosure = { _ in
            coalesceExpectation.fulfill()
        }
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    // MARK: Cancel
    
    func test_cancelDownload_activeDownload() {
        let assetDownloadItem = MockAssetDownloadItem()
        assetDownloadItem.url = url
        
        let assetDownloadItemPauseExpectation = expectation(description: "assetDownloadItemPauseExpectation")
        assetDownloadItem.pauseClosure = {
            assetDownloadItemPauseExpectation.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = assetDownloadItem
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        
        sut.cancelDownload(url: url)
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_cancelDownload_pausedDownload() {
        let assetDownloadItem = MockAssetDownloadItem()
        assetDownloadItem.url = url
        
        assetDownloadItemFactory.assetDownloadItem = assetDownloadItem
        
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
        
        let immediateURL = URL(string: "http://differenturl.com/example")!
        
        let immediateAssetDownloadItem = MockAssetDownloadItem()
        immediateAssetDownloadItem.url = immediateURL
        let immediateResumeExpectation = expectation(description: "immediateResumeExpectation")
        immediateAssetDownloadItem.resumeClosure = {
            immediateResumeExpectation.fulfill()
        }
        
        assetDownloadItemFactory.assetDownloadItem = immediateAssetDownloadItem
        
        sut.scheduleDownload(url: immediateURL, immediateDownload: true) { _ in }
        
        waitForExpectations(timeout: 3, handler: nil)
        
        let assetDownloadItemPauseExpectation = expectation(description: "assetDownloadItemPauseExpectation")
        assetDownloadItem.pauseClosure = {
          assetDownloadItemPauseExpectation.fulfill()
        }
        
        sut.cancelDownload(url: url)
        
        waitForExpectations(timeout: 3, handler: nil)
    }
}

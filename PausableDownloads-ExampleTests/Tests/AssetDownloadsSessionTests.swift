//
//  AssetDownloadsSessionTests.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 15/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import XCTest

@testable import PausableDownloads_Example

class AssetDownloadsSessionTests: XCTestCase {
    
    // MARK: - Tests
    
    // MARK: Init
    
    func test_givenURLSessionFactory_whenInitialised_thenDefaultSessionIsCreatedWithSelfAsDelegateAndNoQueue() {
        let notificationCenter = StubNotificationCenter()
        notificationCenter.objectToReturn = NSObject()
        
        let sessionFactory = StubURLSessionFactory()
        sessionFactory.sessionToReturn = StubURLSession()
        
        let sut = createSUT(urlSessionFactory: sessionFactory,
                            notificationCenter: notificationCenter)
        
        XCTAssertEqual(sessionFactory.events.count, 1)
        
        guard case let .defaultSession(delegate, queue) = sessionFactory.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertTrue(delegate === sut)
        XCTAssertNil(queue)
    }
    
    // MARK: Notification
    
    func test_givenNotificationCenter_whenInitialised_thenObserverIsAddedForMemoryWarningOnMainQueue() {
        let notificationCenter = StubNotificationCenter()
        notificationCenter.objectToReturn = NSObject()
        
        let sessionFactory = StubURLSessionFactory()
        sessionFactory.sessionToReturn = StubURLSession()
        
        _ = createSUT(urlSessionFactory: sessionFactory,
                      notificationCenter: notificationCenter)
        
        XCTAssertEqual(notificationCenter.events.count, 1)
        
        guard case let .addObserver(name, object, queue, _) = notificationCenter.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(name, UIApplication.didReceiveMemoryWarningNotification)
        XCTAssertNil(object)
        XCTAssertTrue(queue === OperationQueue.main)
    }
    
    func test_givenPausedDownload_whenMemoryWarningNotificationIsReceived_thenDownloadTaskIsCancelled() {
        let url = URL(string: "http://test.com/example")!
        
        let notificationCenter = StubNotificationCenter()
        notificationCenter.objectToReturn = NSObject()
        
        let sessionFactory = StubURLSessionFactory()
        let session = StubURLSession()
        sessionFactory.sessionToReturn = session
        
        let sut = createSUT(urlSessionFactory: sessionFactory,
                            notificationCenter: notificationCenter)
        
        guard case let .addObserver(_, _, _, notificationBlock) = notificationCenter.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        sut.scheduleDownload(url: url) { _ in }
        
        XCTAssertEqual(session.events.count, 1)
        
        sut.cancelDownload(url: url)
        
        XCTAssertEqual(downloadTask.events.count, 2)
        
        guard case .cancelByProducingResumeData = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        let notification = Notification(name: UIApplication.didReceiveMemoryWarningNotification)
        notificationBlock(notification)
        
        XCTAssertEqual(downloadTask.events.count, 3)
        
        guard case .cancel = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
    }
    
    func test_givenActiveDownload_whenMemoryWarningNotificationIsReceived_thenTheDownloadTaskIsNotCancelled() {
        let url = URL(string: "http://test.com/example")!
        
        let notificationCenter = StubNotificationCenter()
        notificationCenter.objectToReturn = NSObject()
        
        let sessionFactory = StubURLSessionFactory()
        let session = StubURLSession()
        sessionFactory.sessionToReturn = session
        
        let sut = createSUT(urlSessionFactory: sessionFactory,
                            notificationCenter: notificationCenter)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        guard case let .addObserver(_, _, _, notificationBlock) = notificationCenter.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        sut.scheduleDownload(url: url) { _ in }
        
        XCTAssertEqual(downloadTask.events.count, 1)
        
        let notification = Notification(name: UIApplication.didReceiveMemoryWarningNotification)
        notificationBlock(notification)
        
        XCTAssertEqual(downloadTask.events.count, 1)
        
        guard case .resume = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
    }
    
    // MARK: Schedule
    
    func test_givenNoExistingDownload_whenScheduleDownloadIsCalled_thenDownloadTaskIsCreatedForURLAndResumed() {
        let url = URL(string: "http://test.com/example")!
        
        let notificationCenter = StubNotificationCenter()
        notificationCenter.objectToReturn = NSObject()
        
        let sessionFactory = StubURLSessionFactory()
        let session = StubURLSession()
        sessionFactory.sessionToReturn = session
        
        let sut = createSUT(urlSessionFactory: sessionFactory,
                            notificationCenter: notificationCenter)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        sut.scheduleDownload(url: url) { _ in }
        
        XCTAssertEqual(downloadTask.events.count, 1)
        
        guard case .resume = downloadTask.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(session.events.count, 1)
        
        guard case let .downloadTask(downloadTaskURL, _) = session.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(downloadTaskURL, url)
    }
    
    func test_givenNoExistingDownloads_whenScheduleDownloadIsCalledForTwoDifferentURLs_thenBothDownloadTasksAreResumed() {
        let notificationCenter = StubNotificationCenter()
        notificationCenter.objectToReturn = NSObject()
        
        let sessionFactory = StubURLSessionFactory()
        let session = StubURLSession()
        sessionFactory.sessionToReturn = session
        
        let sut = createSUT(urlSessionFactory: sessionFactory,
                            notificationCenter: notificationCenter)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let urlA = URL(string: "http://example.com/resourceA")!
        let urlB = URL(string: "http://example.com/resourceB")!
        
        sut.scheduleDownload(url: urlA) { _ in }
        sut.scheduleDownload(url: urlB) { _ in }

        XCTAssertEqual(downloadTask.events.count, 2)
        
        guard case .resume = downloadTask.events.first,
              case .resume = downloadTask.events.last else {
            XCTFail("Unexpected events")
            return
        }
    }

    func test_givenInFlightDownload_whenScheduleDownloadIsCalledForTheSameURL_thenNoSecondTaskIsCreatedAndBothCompletionHandlersAreCalled() {
        let url = URL(string: "http://test.com/example")!
        
        let notificationCenter = StubNotificationCenter()
        notificationCenter.objectToReturn = NSObject()
        
        let sessionFactory = StubURLSessionFactory()
        let session = StubURLSession()
        sessionFactory.sessionToReturn = session
        
        let sut = createSUT(urlSessionFactory: sessionFactory,
                            notificationCenter: notificationCenter)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let firstCompletionExpectation = expectation(description: "firstCompletionExpectation")
        sut.scheduleDownload(url: url) { (_) in
            firstCompletionExpectation.fulfill()
        }
        
        let secondCompletionExpectation = expectation(description: "secondCompletionExpectation")
        sut.scheduleDownload(url: url) { (_) in
            secondCompletionExpectation.fulfill()
        }
        
        XCTAssertEqual(downloadTask.events.count, 1)
        
        guard case .resume = downloadTask.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(session.events.count, 1)
        
        guard case let .downloadTask(_, completionHandler) = session.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(nil, nil, nil)
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_givenPausedDownload_whenScheduleDownloadIsCalledForTheSameURL_thenExistingDownloadTaskIsResumed() {
        let url = URL(string: "http://test.com/example")!
        
        let notificationCenter = StubNotificationCenter()
        notificationCenter.objectToReturn = NSObject()
        
        let sessionFactory = StubURLSessionFactory()
        let session = StubURLSession()
        sessionFactory.sessionToReturn = session
        
        let sut = createSUT(urlSessionFactory: sessionFactory,
                            notificationCenter: notificationCenter)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask

        sut.scheduleDownload(url: url) { _ in }
        sut.cancelDownload(url: url)
        
        XCTAssertEqual(downloadTask.events.count, 2)
        
        guard case .cancelByProducingResumeData = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        sut.scheduleDownload(url: url) { _ in }
        
        XCTAssertEqual(downloadTask.events.count, 3)
        
        guard case .resume = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
    }

    func test_givenCompletedDownload_whenScheduleDownloadIsCalledForTheSameURL_thenANewDownloadTaskIsCreated() {
        let url = URL(string: "http://test.com/example")!
        
        let notificationCenter = StubNotificationCenter()
        notificationCenter.objectToReturn = NSObject()
        
        let sessionFactory = StubURLSessionFactory()
        let session = StubURLSession()
        sessionFactory.sessionToReturn = session
        
        let sut = createSUT(urlSessionFactory: sessionFactory,
                            notificationCenter: notificationCenter)
        
        session.downloadTaskToReturn = StubURLSessionDownloadTask()
        
        sut.scheduleDownload(url: url) { (_) in }
        
        XCTAssertEqual(session.events.count, 1)
        
        guard case let .downloadTask(_, completionHandler) = session.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(nil, nil, nil)
        
        sut.scheduleDownload(url: url) { (_) in }
        
        XCTAssertEqual(session.events.count, 2)
    }

    func test_givenScheduledDownload_whenTheDownloadTaskCompletes_thenTheCompletionHandlerIsCalled() {
        let url = URL(string: "http://test.com/example")!
        
        let notificationCenter = StubNotificationCenter()
        notificationCenter.objectToReturn = NSObject()
        
        let sessionFactory = StubURLSessionFactory()
        let session = StubURLSession()
        sessionFactory.sessionToReturn = session
        
        let sut = createSUT(urlSessionFactory: sessionFactory,
                            notificationCenter: notificationCenter)
        
        session.downloadTaskToReturn = StubURLSessionDownloadTask()
        
        let completionExpectation = expectation(description: "completionExpectation")
        sut.scheduleDownload(url: url) { (_) in
            completionExpectation.fulfill()
        }

        guard case let .downloadTask(_, completionHandler) = session.events.first else {
            XCTFail("Unexpected event")
            return
        }

        completionHandler(nil, nil, nil)

        waitForExpectations(timeout: 3, handler: nil)
    }

    func test_givenPausedDownloadWithResumptionData_whenScheduleDownloadIsCalledForTheSameURL_thenDownloadTaskIsCreatedFromResumeData() {
        let url = URL(string: "http://test.com/example")!
        let resumptionData = Data("resumption".utf8)
        
        let notificationCenter = StubNotificationCenter()
        notificationCenter.objectToReturn = NSObject()
        
        let sessionFactory = StubURLSessionFactory()
        let session = StubURLSession()
        sessionFactory.sessionToReturn = session
        
        let sut = createSUT(urlSessionFactory: sessionFactory,
                            notificationCenter: notificationCenter)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        sut.scheduleDownload(url: url) { _ in }
        sut.cancelDownload(url: url)
        
        guard case let .cancelByProducingResumeData(resumeDataHandler) = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        resumeDataHandler(resumptionData)
        
        let resumedDownloadTask = StubURLSessionDownloadTask()
        session.downloadTaskWithResumeDataToReturn = resumedDownloadTask
        
        sut.scheduleDownload(url: url) { _ in }
        
        XCTAssertEqual(session.events.count, 2)
        
        guard case let .downloadTaskWithResumeData(data, _) = session.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(data, resumptionData)
        XCTAssertEqual(resumedDownloadTask.events.count, 1)
        
        guard case .resume = resumedDownloadTask.events.first else {
            XCTFail("Unexpected event")
            return
        }
    }
    
    func test_givenScheduledDownload_whenTheDownloadTaskCompletesWithAFileURL_thenTheCompletionHandlerReceivesTheFileContents() throws {
        let url = URL(string: "http://test.com/example")!
        let fileURL = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: "square", withExtension: "pdf"))
        let expectedData = try Data(contentsOf: fileURL)
        
        XCTAssertFalse(expectedData.isEmpty)
        
        let notificationCenter = StubNotificationCenter()
        notificationCenter.objectToReturn = NSObject()
        
        let sessionFactory = StubURLSessionFactory()
        let session = StubURLSession()
        sessionFactory.sessionToReturn = session
        
        let sut = createSUT(urlSessionFactory: sessionFactory,
                            notificationCenter: notificationCenter)
        
        session.downloadTaskToReturn = StubURLSessionDownloadTask()
        
        var receivedResult: Result<Data, Error>?
        let completionExpectation = expectation(description: "completionExpectation")
        sut.scheduleDownload(url: url) { (result) in
            receivedResult = result
            completionExpectation.fulfill()
        }
        
        guard case let .downloadTask(_, completionHandler) = session.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(fileURL, nil, nil)
        
        waitForExpectations(timeout: 3, handler: nil)
        
        guard case let .success(data) = try XCTUnwrap(receivedResult) else {
            XCTFail("Expected a success result")
            return
        }
        
        XCTAssertEqual(data, expectedData)
    }
    
    func test_givenScheduledDownload_whenTheDownloadTaskCompletesWithAnError_thenTheCompletionHandlerReceivesARetrievalFailure() throws {
        let url = URL(string: "http://test.com/example")!
        
        let notificationCenter = StubNotificationCenter()
        notificationCenter.objectToReturn = NSObject()
        
        let sessionFactory = StubURLSessionFactory()
        let session = StubURLSession()
        sessionFactory.sessionToReturn = session
        
        let sut = createSUT(urlSessionFactory: sessionFactory,
                            notificationCenter: notificationCenter)
        
        session.downloadTaskToReturn = StubURLSessionDownloadTask()
        
        var receivedResult: Result<Data, Error>?
        let completionExpectation = expectation(description: "completionExpectation")
        sut.scheduleDownload(url: url) { (result) in
            receivedResult = result
            completionExpectation.fulfill()
        }
        
        guard case let .downloadTask(_, completionHandler) = session.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(nil, nil, TestError.test)
        
        waitForExpectations(timeout: 3, handler: nil)
        
        guard case let .failure(error) = try XCTUnwrap(receivedResult),
              case let NetworkingError.retrieval(underlyingError) = error else {
            XCTFail("Expected a retrieval failure")
            return
        }
        
        XCTAssertEqual(underlyingError as? TestError, .test)
    }
    
    func test_givenScheduledDownload_whenTheDownloadTaskCompletesWithAnUnreadableFileURL_thenTheCompletionHandlerReceivesAnInvalidDataFailure() throws {
        let url = URL(string: "http://test.com/example")!
        let unreadableFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("does-not-exist-\(UUID().uuidString)")
        
        let notificationCenter = StubNotificationCenter()
        notificationCenter.objectToReturn = NSObject()
        
        let sessionFactory = StubURLSessionFactory()
        let session = StubURLSession()
        sessionFactory.sessionToReturn = session
        
        let sut = createSUT(urlSessionFactory: sessionFactory,
                            notificationCenter: notificationCenter)
        
        session.downloadTaskToReturn = StubURLSessionDownloadTask()
        
        var receivedResult: Result<Data, Error>?
        let completionExpectation = expectation(description: "completionExpectation")
        sut.scheduleDownload(url: url) { (result) in
            receivedResult = result
            completionExpectation.fulfill()
        }
        
        guard case let .downloadTask(_, completionHandler) = session.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(unreadableFileURL, nil, nil)
        
        waitForExpectations(timeout: 3, handler: nil)
        
        guard case let .failure(error) = try XCTUnwrap(receivedResult),
              case NetworkingError.invalidData = error else {
            XCTFail("Expected an invalid data failure")
            return
        }
    }
    
    func test_givenTwoCoalescedDownloads_whenTheDownloadTaskCompletes_thenBothCompletionHandlersReceiveTheSameData() throws {
        let url = URL(string: "http://test.com/example")!
        let fileURL = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: "square", withExtension: "pdf"))
        let expectedData = try Data(contentsOf: fileURL)
        
        let notificationCenter = StubNotificationCenter()
        notificationCenter.objectToReturn = NSObject()
        
        let sessionFactory = StubURLSessionFactory()
        let session = StubURLSession()
        sessionFactory.sessionToReturn = session
        
        let sut = createSUT(urlSessionFactory: sessionFactory,
                            notificationCenter: notificationCenter)
        
        session.downloadTaskToReturn = StubURLSessionDownloadTask()
        
        var firstReceivedResult: Result<Data, Error>?
        let firstCompletionExpectation = expectation(description: "firstCompletionExpectation")
        sut.scheduleDownload(url: url) { (result) in
            firstReceivedResult = result
            firstCompletionExpectation.fulfill()
        }
        
        var secondReceivedResult: Result<Data, Error>?
        let secondCompletionExpectation = expectation(description: "secondCompletionExpectation")
        sut.scheduleDownload(url: url) { (result) in
            secondReceivedResult = result
            secondCompletionExpectation.fulfill()
        }
        
        guard case let .downloadTask(_, completionHandler) = session.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(fileURL, nil, nil)
        
        waitForExpectations(timeout: 3, handler: nil)
        
        guard case let .success(firstData) = try XCTUnwrap(firstReceivedResult),
              case let .success(secondData) = try XCTUnwrap(secondReceivedResult) else {
            XCTFail("Expected both handlers to receive a success result")
            return
        }
        
        XCTAssertEqual(firstData, expectedData)
        XCTAssertEqual(secondData, expectedData)
    }
    
    // MARK: Cancel

    func test_givenScheduledDownload_whenCancelDownloadIsCalled_thenDownloadTaskIsCancelledByProducingResumeData() {
        let url = URL(string: "http://test.com/example")!
        
        let notificationCenter = StubNotificationCenter()
        notificationCenter.objectToReturn = NSObject()
        
        let sessionFactory = StubURLSessionFactory()
        let session = StubURLSession()
        sessionFactory.sessionToReturn = session
        
        let sut = createSUT(urlSessionFactory: sessionFactory,
                            notificationCenter: notificationCenter)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        sut.scheduleDownload(url: url) { _ in }
        sut.cancelDownload(url: url)

        XCTAssertEqual(downloadTask.events.count, 2)
        
        guard case .cancelByProducingResumeData = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
    }
    
    func test_givenNoScheduledDownloads_whenCancelDownloadIsCalledForAnUnknownURL_thenNoDownloadTaskEventsAreRecorded() {
        let unknownURL = URL(string: "http://test.com/unknown")!
        
        let notificationCenter = StubNotificationCenter()
        notificationCenter.objectToReturn = NSObject()
        
        let sessionFactory = StubURLSessionFactory()
        let session = StubURLSession()
        sessionFactory.sessionToReturn = session
        
        let sut = createSUT(urlSessionFactory: sessionFactory,
                            notificationCenter: notificationCenter)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        sut.cancelDownload(url: unknownURL)
        
        XCTAssertTrue(session.events.isEmpty)
        XCTAssertTrue(downloadTask.events.isEmpty)
    }
}

extension AssetDownloadsSessionTests {
    func createSUT(urlSessionFactory: URLSessionFactoryType = StubURLSessionFactory(),
                   notificationCenter: NotificationCenterType = StubNotificationCenter()) -> AssetDownloadsSession {
        AssetDownloadsSession(urlSessionFactory: urlSessionFactory,
                              notificationCenter: notificationCenter)
    }
}

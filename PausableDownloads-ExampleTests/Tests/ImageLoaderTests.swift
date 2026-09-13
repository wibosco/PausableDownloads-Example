//
//  ImageLoaderTests.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 12/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import XCTest
import UIKit

@testable import PausableDownloads_Example

final class ImageLoaderTests: XCTestCase {
    private var cacheDirectory: URL!
    
    // MARK: - Lifecycle
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        cacheDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: cacheDirectory,
                                                withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: cacheDirectory)
        cacheDirectory = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Tests
    
    // MARK: Load
    
    func test_givenNothingCached_whenLoadIsCalled_thenTheImageIsDownloadedAndItsTokenIsReturned() {
        let downloader = StubDownloader()
        
        let image = ImageDomainModel.testData()
        let token = DownloadToken(url: image.url)
        downloader.tokenToReturn = token
        
        let fileManager = StubFileManager()
        fileManager.urlsToReturn = [cacheDirectory]
        
        let sut = createSUT(downloader: downloader,
                            fileManager: fileManager)
        
        let returnedToken = sut.load(image,
                                     callbackQueue: .main) { _ in }
        
        XCTAssertEqual(returnedToken, token)
        XCTAssertEqual(downloader.events.count, 1)
        
        guard case let .download(downloadedURL, _) = downloader.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(downloadedURL, image.url)
    }
    
    func test_givenDownloadInProgress_whenItCompletesWithImageData_thenTheImageIsDeliveredOnTheCallbackQueue() throws {
        let downloader = StubDownloader()
        downloader.tokenToReturn = DownloadToken(url: ImageDomainModel.testData().url)
        
        let fileManager = StubFileManager()
        fileManager.urlsToReturn = [cacheDirectory]
        
        let sut = createSUT(downloader: downloader,
                            fileManager: fileManager)
        
        let callbackQueue = DispatchQueue(label: "com.williamboles.imageloadertests")
        
        var receivedResult: Result<UIImage, Error>?
        let completionExpectation = expectation(description: "completionExpectation")
        sut.load(ImageDomainModel.testData(),
                 callbackQueue: callbackQueue) { result in
            dispatchPrecondition(condition: .onQueue(callbackQueue))
            
            receivedResult = result
            completionExpectation.fulfill()
        }
        
        guard case let .download(_, completionHandler) = downloader.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.success(.imageTestData()))
        
        waitForExpectations(timeout: 3, handler: nil)
        
        guard case .success = try XCTUnwrap(receivedResult) else {
            XCTFail("Expected a success result")
            return
        }
    }
    
    func test_givenDownloadInProgress_whenItCompletesWithImageData_thenTheImageIsCached() throws {
        let downloader = StubDownloader()
        
        let image = ImageDomainModel.testData(identifier: "a",
                                              url: URL(string: "http://test.com/a.jpg")!)
        downloader.tokenToReturn = DownloadToken(url: image.url)
        
        let fileManager = StubFileManager()
        fileManager.urlsToReturn = [cacheDirectory]
        
        let sut = createSUT(downloader: downloader,
                            fileManager: fileManager)
        
        let data = Data.imageTestData()
        
        let completionExpectation = expectation(description: "completionExpectation")
        sut.load(image,
                 callbackQueue: .main) { _ in
            completionExpectation.fulfill()
        }
        
        guard case let .download(_, completionHandler) = downloader.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.success(data))
        
        waitForExpectations(timeout: 3, handler: nil)
        
        //named for the image so a later load of the same image finds it
        let cachedFileURL = cacheDirectory.appendingPathComponent("a.jpg")
        
        XCTAssertEqual(try Data(contentsOf: cachedFileURL), data)
    }
    
    func test_givenCachedImage_whenLoadIsCalled_thenTheCachedImageIsDeliveredWithoutADownload() throws {
        let downloader = StubDownloader()
        
        let image = ImageDomainModel.testData(identifier: "a",
                                              url: URL(string: "http://test.com/a.jpg")!)
        
        try Data.imageTestData().write(to: cacheDirectory.appendingPathComponent("a.jpg"))
        
        let fileManager = StubFileManager()
        fileManager.urlsToReturn = [cacheDirectory]
        
        let sut = createSUT(downloader: downloader,
                            fileManager: fileManager)
        
        var receivedResult: Result<UIImage, Error>?
        let completionExpectation = expectation(description: "completionExpectation")
        let token = sut.load(image,
                             callbackQueue: .main) { result in
            receivedResult = result
            completionExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 3, handler: nil)
        
        //nothing is in flight, so there is nothing for the caller to cancel
        XCTAssertNil(token)
        XCTAssertTrue(downloader.events.isEmpty)
        
        guard case .success = try XCTUnwrap(receivedResult) else {
            XCTFail("Expected a success result")
            return
        }
    }
    
    func test_givenDownloadInProgress_whenItCompletesWithDataThatIsNotAnImage_thenAnInvalidDataFailureIsDelivered() throws {
        let downloader = StubDownloader()
        downloader.tokenToReturn = DownloadToken(url: ImageDomainModel.testData().url)
        
        let fileManager = StubFileManager()
        fileManager.urlsToReturn = [cacheDirectory]
        
        let sut = createSUT(downloader: downloader,
                            fileManager: fileManager)
        
        var receivedResult: Result<UIImage, Error>?
        let completionExpectation = expectation(description: "completionExpectation")
        sut.load(ImageDomainModel.testData(),
                 callbackQueue: .main) { result in
            receivedResult = result
            completionExpectation.fulfill()
        }
        
        guard case let .download(_, completionHandler) = downloader.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.success(Data("not an image".utf8)))
        
        waitForExpectations(timeout: 3, handler: nil)
        
        guard case let .failure(error) = try XCTUnwrap(receivedResult),
              case ImageLoaderError.invalidImageData = error else {
            XCTFail("Expected an invalid data failure")
            return
        }
    }
    
    func test_givenDownloadInProgress_whenItFails_thenTheFailureIsPassedOn() throws {
        let downloader = StubDownloader()
        downloader.tokenToReturn = DownloadToken(url: ImageDomainModel.testData().url)
        
        let fileManager = StubFileManager()
        fileManager.urlsToReturn = [cacheDirectory]
        
        let sut = createSUT(downloader: downloader,
                            fileManager: fileManager)
        
        var receivedResult: Result<UIImage, Error>?
        let completionExpectation = expectation(description: "completionExpectation")
        sut.load(ImageDomainModel.testData(),
                 callbackQueue: .main) { result in
            receivedResult = result
            completionExpectation.fulfill()
        }
        
        guard case let .download(_, completionHandler) = downloader.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.failure(TestError.test))
        
        waitForExpectations(timeout: 3, handler: nil)
        
        guard case let .failure(error) = try XCTUnwrap(receivedResult) else {
            XCTFail("Expected a failure result")
            return
        }
        
        XCTAssertEqual(error as? TestError, .test)
    }
    
    // MARK: Cancel
    
    func test_givenLoadInProgress_whenCancelIsCalled_thenTheDownloadIsPaused() throws {
        let downloader = StubDownloader()
        
        let image = ImageDomainModel.testData()
        let token = DownloadToken(url: image.url)
        downloader.tokenToReturn = token
        
        let fileManager = StubFileManager()
        fileManager.urlsToReturn = [cacheDirectory]
        
        let sut = createSUT(downloader: downloader,
                            fileManager: fileManager)
        
        let loadToken = sut.load(image,
                                 callbackQueue: .main) { _ in }
        
        sut.cancel(try XCTUnwrap(loadToken))
        
        XCTAssertEqual(downloader.events.count, 2)
        
        guard case let .pause(pausedToken) = downloader.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(pausedToken, token)
    }
}

extension ImageLoaderTests {
    func createSUT(downloader: Downloader = StubDownloader(),
                   fileManager: FileManager = StubFileManager()) -> DefaultImageLoader {
        DefaultImageLoader(downloader: downloader,
                           fileManager: fileManager)
    }
}

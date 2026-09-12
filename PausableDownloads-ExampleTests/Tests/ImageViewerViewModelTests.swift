//
//  ImageViewerViewModelTests.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import XCTest

@testable import PausableDownloads_Example

final class ImageViewerViewModelTests: XCTestCase {
    
    // MARK: - Tests
    
    // MARK: Init
    
    func test_givenImage_whenInitialised_thenStateIsReady() {
        let image = ImageDomainModel.testData(identifier: "a",
                                              url: URL(string: "http://test.com/a.jpg")!)
        
        let sut = createSUT(imageDomainModel: image)
        
        XCTAssertEqual(sut.state, .ready)
    }
    
    // MARK: Load
    
    func test_givenViewModel_whenLoadIsCalled_thenTheAssetIsRequested() {
        let imageLoader = StubImageLoader()
        let image = ImageDomainModel.testData(identifier: "a",
                                              url: URL(string: "http://test.com/a.jpg")!)
        
        let sut = createSUT(imageDomainModel: image,
                            imageLoader: imageLoader)
        
        sut.loadImage()
        
        XCTAssertEqual(imageLoader.events.count, 1)
        
        guard case let .load(loadedImage, callbackQueue, _) = imageLoader.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(loadedImage, image)
        XCTAssertTrue(callbackQueue === DispatchQueue.main)
        XCTAssertEqual(sut.state, .loading)
    }
    
    func test_givenAssetLoadInProgress_whenTheAssetLoads_thenStateTransitionsToLoadedAsset() {
        let imageLoader = StubImageLoader()
        let image = ImageDomainModel.testData(identifier: "a",
                                              url: URL(string: "http://test.com/a.jpg")!)
        
        let sut = createSUT(imageDomainModel: image,
                            imageLoader: imageLoader)
        
        sut.loadImage()
        
        guard case let .load(_, _, completionHandler) = imageLoader.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        let loadedImage = UIImage()
        completionHandler(.success(loadedImage))
        
        XCTAssertEqual(sut.state, .loaded(loadedImage))
    }
    
    func test_givenAssetLoadInProgress_whenTheAssetFailsToLoad_thenStateTransitionsToFailed() {
        let imageLoader = StubImageLoader()
        
        let sut = createSUT(imageLoader: imageLoader)
        
        sut.loadImage()
        
        guard case let .load(_, _, completionHandler) = imageLoader.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.failure(TestError.test))
        
        XCTAssertEqual(sut.state, .failed)
    }
    
    func test_givenAssetLoadInProgress_whenLoadIsCalledAgain_thenTheAssetIsNotRequestedASecondTime() {
        let imageLoader = StubImageLoader()
        
        let sut = createSUT(imageLoader: imageLoader)
        
        sut.loadImage()
        sut.loadImage()
        
        XCTAssertEqual(imageLoader.events.count, 1)
    }
    
    func test_givenLoadedAsset_whenLoadIsCalledAgain_thenTheAssetIsNotRequestedASecondTime() {
        let imageLoader = StubImageLoader()
        let image = ImageDomainModel.testData(identifier: "a",
                                              url: URL(string: "http://test.com/a.jpg")!)
        
        let sut = createSUT(imageDomainModel: image,
                            imageLoader: imageLoader)
        
        sut.loadImage()
        
        guard case let .load(_, _, completionHandler) = imageLoader.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        let loadedImage = UIImage()
        completionHandler(.success(loadedImage))
        
        sut.loadImage()
        
        XCTAssertEqual(imageLoader.events.count, 1)
        XCTAssertEqual(sut.state, .loaded(loadedImage))
    }
    
    // MARK: Pause
    
    func test_givenAssetLoadInProgress_whenPauseIsCalled_thenTheAssetLoadIsCancelledAndStateReturnsToReady() {
        let imageLoader = StubImageLoader()
        let image = ImageDomainModel.testData(identifier: "a",
                                              url: URL(string: "http://test.com/a.jpg")!)
        
        let token = LoadToken(url: image.url)
        imageLoader.tokenToReturn = token
        
        let sut = createSUT(imageDomainModel: image,
                            imageLoader: imageLoader)
        
        sut.loadImage()
        sut.cancelImageLoad()
        
        XCTAssertEqual(imageLoader.events.count, 2)
        
        guard case let .cancel(cancelledToken) = imageLoader.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        //the view model pauses the download it started, not whatever shares the URL
        XCTAssertEqual(cancelledToken, token)
        XCTAssertEqual(sut.state, .ready)
    }
    
    func test_givenNoAssetLoadInProgress_whenPauseIsCalled_thenNothingIsCancelled() {
        let imageLoader = StubImageLoader()
        
        let sut = createSUT(imageLoader: imageLoader)
        
        sut.cancelImageLoad()
        
        XCTAssertTrue(imageLoader.events.isEmpty)
    }
    
    func test_givenAssetServedFromTheCache_whenPauseIsCalled_thenNothingIsCancelled() {
        let imageLoader = StubImageLoader()
        
        //a cache hit has nothing in flight, so the loader hands back no token
        imageLoader.tokenToReturn = nil
        
        let sut = createSUT(imageLoader: imageLoader)
        
        sut.loadImage()
        
        guard case let .load(_, _, completionHandler) = imageLoader.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        let loadedImage = UIImage()
        completionHandler(.success(loadedImage))
        
        sut.cancelImageLoad()
        
        XCTAssertEqual(imageLoader.events.count, 1)
        XCTAssertEqual(sut.state, .loaded(loadedImage))
    }
    
    func test_givenPausedAssetLoad_whenLoadIsCalledAgain_thenTheAssetIsRequestedAgain() {
        let imageLoader = StubImageLoader()
        let image = ImageDomainModel.testData()
        
        imageLoader.tokenToReturn = LoadToken(url: image.url)
        
        let sut = createSUT(imageDomainModel: image,
                            imageLoader: imageLoader)
        
        sut.loadImage()
        sut.cancelImageLoad()
        sut.loadImage()
        
        XCTAssertEqual(imageLoader.events.count, 3)
        
        guard case .load = imageLoader.events.last else {
            XCTFail("Unexpected event")
            return
        }
    }
}

extension ImageViewerViewModelTests {
    func createSUT(imageDomainModel: ImageDomainModel = .testData(),
                   imageLoader: ImageLoader = StubImageLoader()) -> ImageViewerViewModel {
        ImageViewerViewModel(imageDomainModel: imageDomainModel,
                             imageLoader: imageLoader)
    }
}

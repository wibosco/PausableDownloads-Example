//
//  ImageGalleryViewModelTests.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import XCTest

@testable import PausableDownloads_Example

final class ImageGalleryViewModelTests: XCTestCase {
    
    // MARK: - Tests
    
    // MARK: Load
    
    func test_givenViewModel_whenLoadIsCalled_thenImagesAreRetrievedOnTheMainQueue() {
        let imagesService = StubImagesService()
        let delegate = StubImageGalleryViewModelDelegate()
        
        let sut = createSUT(imagesService: imagesService)
        sut.delegate = delegate
        
        sut.load()
        
        XCTAssertEqual(imagesService.events.count, 1)
        
        guard case let .load(callbackQueue, _) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertTrue(callbackQueue === DispatchQueue.main)
        XCTAssertEqual(sut.state, .loading)
        
        guard case let .didChangeTo(state) = delegate.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(state, .loading)
    }
    
    func test_givenLoadInProgress_whenImagesAreRetrieved_thenTheFirstAssetIsLoaded() {
        let imagesService = StubImagesService()
        let imageLoader = StubImageLoader()
        
        let imageA = ImageDomainModel.testData(identifier: "a",
                                               url: URL(string: "http://test.com/a.jpg")!)
        let imageB = ImageDomainModel.testData(identifier: "b",
                                               url: URL(string: "http://test.com/b.jpg")!)
        
        let sut = createSUT(imagesService: imagesService,
                            imageLoader: imageLoader)
        
        sut.load()
        
        guard case let .load(_, completionHandler) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.success([imageA, imageB]))
        
        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.numberOfImages, 2)
        XCTAssertEqual(sut.currentIndex, 0)
        
        XCTAssertEqual(imageLoader.events.count, 1)
        
        guard case let .load(loadedImage, _, _) = imageLoader.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(loadedImage, imageA)
    }
    
    func test_givenLoadInProgress_whenImageRetrievalFails_thenStateTransitionsToFailed() {
        let imagesService = StubImagesService()
        let imageLoader = StubImageLoader()
        
        let sut = createSUT(imagesService: imagesService,
                            imageLoader: imageLoader)
        
        sut.load()
        
        guard case let .load(_, completionHandler) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.failure(TestError.test))
        
        XCTAssertEqual(sut.state, .failed)
        XCTAssertTrue(imageLoader.events.isEmpty)
    }
    
    func test_givenLoadInProgress_whenNoImagesAreRetrieved_thenNoAssetIsLoaded() {
        let imagesService = StubImagesService()
        let imageLoader = StubImageLoader()
        
        let sut = createSUT(imagesService: imagesService,
                            imageLoader: imageLoader)
        
        sut.load()
        
        guard case let .load(_, completionHandler) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.success([]))
        
        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.numberOfImages, 0)
        XCTAssertTrue(imageLoader.events.isEmpty)
    }
    
    // MARK: Pages
    
    func test_givenRetrievedImages_whenAViewModelIsRequestedTwiceForTheSameIndex_thenTheSameInstanceIsReturned() {
        let imagesService = StubImagesService()
        
        let imageA = ImageDomainModel.testData(identifier: "a",
                                               url: URL(string: "http://test.com/a.jpg")!)
        let imageB = ImageDomainModel.testData(identifier: "b",
                                               url: URL(string: "http://test.com/b.jpg")!)
        
        let sut = createSUT(imagesService: imagesService)
        
        sut.load()
        
        guard case let .load(_, completionHandler) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.success([imageA, imageB]))
        
        let first = sut.viewModel(at: 1)
        let second = sut.viewModel(at: 1)
        
        XCTAssertNotNil(first)
        XCTAssertTrue(first === second)
    }
    
    func test_givenRetrievedImages_whenAViewModelIsRequestedForEachIndex_thenItRepresentsThatImage() {
        let imagesService = StubImagesService()
        
        let imageA = ImageDomainModel.testData(identifier: "a",
                                               url: URL(string: "http://test.com/a.jpg")!)
        let imageB = ImageDomainModel.testData(identifier: "b",
                                               url: URL(string: "http://test.com/b.jpg")!)
        
        let sut = createSUT(imagesService: imagesService)
        
        sut.load()
        
        guard case let .load(_, completionHandler) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.success([imageA, imageB]))
        
        XCTAssertEqual(sut.viewModel(at: 0)?.imageDomainModel, imageA)
        XCTAssertEqual(sut.viewModel(at: 1)?.imageDomainModel, imageB)
    }
    
    func test_givenRetrievedImages_whenAViewModelIsRequestedOutOfBounds_thenNilIsReturned() {
        let imagesService = StubImagesService()
        
        let imageA = ImageDomainModel.testData(identifier: "a",
                                               url: URL(string: "http://test.com/a.jpg")!)
        let imageB = ImageDomainModel.testData(identifier: "b",
                                               url: URL(string: "http://test.com/b.jpg")!)
        
        let sut = createSUT(imagesService: imagesService)
        
        sut.load()
        
        guard case let .load(_, completionHandler) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.success([imageA, imageB]))
        
        XCTAssertNil(sut.viewModel(at: -1))
        XCTAssertNil(sut.viewModel(at: 2))
    }
    
    // MARK: Move
    
    func test_givenLoadedImages_whenMoveToIsCalled_thenTheOutgoingAssetIsPausedAndTheIncomingOneIsLoaded() {
        let imagesService = StubImagesService()
        let imageLoader = StubImageLoader()
        
        let imageA = ImageDomainModel.testData(identifier: "a",
                                               url: URL(string: "http://test.com/a.jpg")!)
        let imageB = ImageDomainModel.testData(identifier: "b",
                                               url: URL(string: "http://test.com/b.jpg")!)
        
        let tokenForImageA = LoadToken(url: imageA.url)
        imageLoader.tokenToReturn = tokenForImageA
        
        let sut = createSUT(imagesService: imagesService,
                            imageLoader: imageLoader)
        
        sut.load()
        
        guard case let .load(_, completionHandler) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.success([imageA, imageB]))
        
        //the token the next load hands back, so the paused one is identifiable
        imageLoader.tokenToReturn = LoadToken(url: imageB.url)
        
        sut.move(to: 1)
        
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(imageLoader.events.count, 3)
        
        guard case let .cancel(pausedToken) = imageLoader.events[1] else {
            XCTFail("Unexpected event")
            return
        }
        
        //the download issued for imageA, which is the page being swiped away from
        XCTAssertEqual(pausedToken, tokenForImageA)
        
        guard case let .load(loadedImage, _, _) = imageLoader.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(loadedImage, imageB)
    }
    
    func test_givenAPausedImage_whenMovedBackTo_thenItsAssetIsLoadedAgain() {
        let imagesService = StubImagesService()
        let imageLoader = StubImageLoader()
        
        let imageA = ImageDomainModel.testData(identifier: "a",
                                               url: URL(string: "http://test.com/a.jpg")!)
        let imageB = ImageDomainModel.testData(identifier: "b",
                                               url: URL(string: "http://test.com/b.jpg")!)
        
        imageLoader.tokenToReturn = LoadToken(url: imageA.url)
        
        let sut = createSUT(imagesService: imagesService,
                            imageLoader: imageLoader)
        
        sut.load()
        
        guard case let .load(_, completionHandler) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.success([imageA, imageB]))
        
        let tokenForImageB = LoadToken(url: imageB.url)
        imageLoader.tokenToReturn = tokenForImageB
        
        sut.move(to: 1)
        
        imageLoader.tokenToReturn = LoadToken(url: imageA.url)
        
        sut.move(to: 0)
        
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(imageLoader.events.count, 5)
        
        guard case let .cancel(pausedToken) = imageLoader.events[3] else {
            XCTFail("Unexpected event")
            return
        }
        
        //the download issued for imageB, which is the page being swiped away from
        XCTAssertEqual(pausedToken, tokenForImageB)
        
        /* Rescheduling the same URL is what hands the paused download back to the
         session to resume rather than restart.
         */
        guard case let .load(loadedImage, _, _) = imageLoader.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(loadedImage, imageA)
    }
    
    func test_givenLoadedImages_whenMoveToIsCalledForTheCurrentIndex_thenNothingHappens() {
        let imagesService = StubImagesService()
        let imageLoader = StubImageLoader()
        
        let imageA = ImageDomainModel.testData(identifier: "a",
                                               url: URL(string: "http://test.com/a.jpg")!)
        let imageB = ImageDomainModel.testData(identifier: "b",
                                               url: URL(string: "http://test.com/b.jpg")!)
        
        let sut = createSUT(imagesService: imagesService,
                            imageLoader: imageLoader)
        
        sut.load()
        
        guard case let .load(_, completionHandler) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.success([imageA, imageB]))
        
        let eventCountBeforeMove = imageLoader.events.count
        
        sut.move(to: 0)
        
        XCTAssertEqual(imageLoader.events.count, eventCountBeforeMove)
        XCTAssertEqual(sut.currentIndex, 0)
    }
    
    func test_givenLoadedImages_whenMoveToIsCalledOutOfBounds_thenNothingHappens() {
        let imagesService = StubImagesService()
        let imageLoader = StubImageLoader()
        
        let imageA = ImageDomainModel.testData(identifier: "a",
                                               url: URL(string: "http://test.com/a.jpg")!)
        let imageB = ImageDomainModel.testData(identifier: "b",
                                               url: URL(string: "http://test.com/b.jpg")!)
        
        let sut = createSUT(imagesService: imagesService,
                            imageLoader: imageLoader)
        
        sut.load()
        
        guard case let .load(_, completionHandler) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.success([imageA, imageB]))
        
        let eventCountBeforeMove = imageLoader.events.count
        
        sut.move(to: 2)
        sut.move(to: -1)
        
        XCTAssertEqual(imageLoader.events.count, eventCountBeforeMove)
        XCTAssertEqual(sut.currentIndex, 0)
    }
}

extension ImageGalleryViewModelTests {
    func createSUT(imagesService: ImagesService = StubImagesService(),
                   imageLoader: ImageLoader = StubImageLoader()) -> ImageGalleryViewModel {
        ImageGalleryViewModel(imagesService: imagesService,
                              imageLoader: imageLoader)
    }
}

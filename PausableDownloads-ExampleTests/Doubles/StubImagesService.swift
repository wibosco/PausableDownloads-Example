//
//  StubImagesService.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation

@testable import PausableDownloads_Example

final class StubImagesService: ImagesService {
    enum Event {
        case retrieveImages(((_ result: Result<[ImageDomainModel], Error>) -> ()))
    }
    
    private(set) var events = [Event]()
    
    func retrieveImages(completionHandler: @escaping ((_ result: Result<[ImageDomainModel], Error>) -> ())) {
        events.append(.retrieveImages(completionHandler))
    }
}

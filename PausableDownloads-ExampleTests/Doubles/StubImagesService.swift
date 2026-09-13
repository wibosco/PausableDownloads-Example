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
        case load(DispatchQueue, LoadImagesCompletionHandler)
    }
    
    private(set) var events = [Event]()
    
    func load(callbackQueue: DispatchQueue,
              completionHandler: @escaping LoadImagesCompletionHandler) {
        events.append(.load(callbackQueue, completionHandler))
    }
}

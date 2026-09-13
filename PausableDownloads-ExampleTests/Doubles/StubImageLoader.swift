//
//  StubImageLoader.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation

@testable import PausableDownloads_Example

final class StubImageLoader: ImageLoader {
    enum Event {
        case load(ImageDomainModel, DispatchQueue, LoadImageCompletionHandler)
        case cancel(LoadToken)
    }
    
    private(set) var events = [Event]()
    
    var tokenToReturn: LoadToken?
    
    @discardableResult
    func load(_ imageDomainModel: ImageDomainModel,
              callbackQueue: DispatchQueue,
              completionHandler: @escaping LoadImageCompletionHandler) -> LoadToken? {
        events.append(.load(imageDomainModel, callbackQueue, completionHandler))
        
        return tokenToReturn
    }
    
    func cancel(_ token: LoadToken) {
        events.append(.cancel(token))
    }
}

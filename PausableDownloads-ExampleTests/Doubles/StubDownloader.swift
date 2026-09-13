//
//  StubDownloader.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 11/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation

@testable import PausableDownloads_Example

final class StubDownloader: Downloader {
    enum Event {
        case download(URL, DownloadCompletionHandler)
        case pause(DownloadToken)
    }
    
    private(set) var events = [Event]()
    
    var tokenToReturn: DownloadToken!
    
    func download(_ url: URL,
                  completionHandler: @escaping DownloadCompletionHandler) -> DownloadToken {
        events.append(.download(url, completionHandler))
        
        return tokenToReturn
    }
    
    func pause(_ token: DownloadToken) {
        events.append(.pause(token))
    }
}

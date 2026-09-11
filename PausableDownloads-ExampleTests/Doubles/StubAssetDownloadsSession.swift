//
//  StubAssetDownloadsSession.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 11/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation

@testable import PausableDownloads_Example

final class StubAssetDownloadsSession: AssetDownloadsSession {
    enum Event {
        case scheduleDownload(URL, DownloadCompletionHandler)
        case pauseDownload(DownloadToken)
    }
    
    private(set) var events = [Event]()
    
    var tokenToReturn: DownloadToken!
    
    func scheduleDownload(url: URL,
                          completionHandler: @escaping DownloadCompletionHandler) -> DownloadToken {
        events.append(.scheduleDownload(url, completionHandler))
        
        return tokenToReturn
    }
    
    func pauseDownload(_ token: DownloadToken) {
        events.append(.pauseDownload(token))
    }
}

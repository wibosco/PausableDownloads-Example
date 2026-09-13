//
//  StubFileManager.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 12/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation

final class StubFileManager: FileManager {
    enum Event {
        case urls(FileManager.SearchPathDirectory, FileManager.SearchPathDomainMask)
    }
    
    private(set) var events = [Event]()
    
    var urlsToReturn = [URL]()
    
    override func urls(for directory: FileManager.SearchPathDirectory,
                       in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        events.append(.urls(directory, domainMask))
        
        return urlsToReturn
    }
}

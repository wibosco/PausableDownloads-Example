//
//  StubDownloadSession.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 13/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

@testable import PausableDownloads_Example

class StubDownloadSession: DownloadSession {
    enum Event {
        case downloadTask(URL)
        case downloadTaskWithResumeData(Data)
    }
    
    private(set) var events = [Event]()
    
    var downloadTaskToReturn: StubDownloadTask!
    var downloadTaskWithResumeDataToReturn: StubDownloadTask!
    
    func downloadTask(with url: URL) -> DownloadTask {
        events.append(.downloadTask(url))
        
        return downloadTaskToReturn
    }
    
    func downloadTask(withResumeData resumeData: Data) -> DownloadTask {
        events.append(.downloadTaskWithResumeData(resumeData))
        
        return downloadTaskWithResumeDataToReturn
    }
}

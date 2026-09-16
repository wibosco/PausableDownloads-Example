//
//  StubImageViewerViewModelDelegate.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation

@testable import PausableDownloads_Example

final class StubImageViewerViewModelDelegate: ImageViewerViewModelDelegate {
    enum Event {
        case didChangeTo(ImageViewerViewModel.State)
    }
    
    private(set) var events = [Event]()
    
    func viewModel(_ viewModel: ImageViewerViewModel,
                   didChangeTo state: ImageViewerViewModel.State) {
        events.append(.didChangeTo(state))
    }
}

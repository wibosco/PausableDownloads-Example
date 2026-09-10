//
//  StubImageGalleryViewModelDelegate.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation

@testable import PausableDownloads_Example

final class StubImageGalleryViewModelDelegate: ImageGalleryViewModelDelegate {
    enum Event {
        case didChangeTo(ImageGalleryViewModel.State)
    }
    
    private(set) var events = [Event]()
    
    func viewModel(_ viewModel: ImageGalleryViewModel,
                   didChangeTo state: ImageGalleryViewModel.State) {
        events.append(.didChangeTo(state))
    }
}

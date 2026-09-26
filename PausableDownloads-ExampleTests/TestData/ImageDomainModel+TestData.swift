//
//  ImageDomainModel+TestData.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation

@testable import PausableDownloads_Example

extension ImageDomainModel {
    
    static func testData(identifier: String = "test_example",
                         url: URL = URL(string: "http://test.com/example.jpg")!,
                         width: Int = 100,
                         height: Int = 200) -> ImageDomainModel {
        ImageDomainModel(identifier: identifier,
                         url: url,
                         width: width,
                         height: height)
    }
}

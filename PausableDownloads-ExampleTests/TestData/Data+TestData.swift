//
//  Data+TestData.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 12/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation
import UIKit

extension Data {
    
    static func imageTestData(size: CGSize = CGSize(width: 1, height: 1),
                              color: UIColor = .red) -> Data {
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.pngData { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

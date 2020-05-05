//
//  Parser.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 12/11/2017.
//  Copyright © 2017 William Boles. All rights reserved.
//

import Foundation

class Parser<T> {
    
    // MARK: - Parse
    
    func parseResponse(_ response: [String: Any]) -> T {
        fatalError("Subclass needs to override this method")
    }
}

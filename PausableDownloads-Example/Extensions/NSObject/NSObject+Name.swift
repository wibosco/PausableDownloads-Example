//
//  NSObject+Name.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 29/06/2017.
//  Copyright © 2017 William Boles. All rights reserved.
//

import Foundation

extension NSObject {
    
    var className: String {
        return String(describing: type(of: self))
    }
    
    class var className: String {
        return String(describing: self)
    }
}

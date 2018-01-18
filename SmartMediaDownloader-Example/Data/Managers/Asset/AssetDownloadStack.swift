//
//  AssetDownloadStack.swift
//  SmartMediaDownloader-Example
//
//  Created by William Boles on 15/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

class AssetDownloadStack {
    
    private var stack = [AssetDownloadItem]()
    
    // MARK: - Push
    
    func push(assetDownloadItem: AssetDownloadItem, forceDownload: Bool = false) {
        stack.append(assetDownloadItem)
    }
    
    // MARK: - Pop
    
    func pop() -> AssetDownloadItem? {
        return stack.removeLast()
    }
}

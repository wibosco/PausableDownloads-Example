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
        print("Pushed \(assetDownloadItem.task.currentRequest?.url?.absoluteString ?? "unknown") onto stack")
        stack.append(assetDownloadItem)
        print("Stack has \(stack.count) item(s)")
    }
    
    // MARK: - Pop
    
    func pop() -> AssetDownloadItem? {
        guard let item = peek() else {
            return nil
        }
        
        print("Popping \(item.task.currentRequest?.url?.absoluteString ?? "unknown") from stack")
        stack.removeLast()
        print("Stack has \(stack.count) item(s)")
        
        return item
    }
    
    func peek() -> AssetDownloadItem? {
        return stack.last
    }
    
    // MARK: - Count
    
    var count: Int {
        return stack.count
    }
}

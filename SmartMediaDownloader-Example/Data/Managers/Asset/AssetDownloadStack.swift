//
//  AssetDownloadStack.swift
//  SmartMediaDownloader-Example
//
//  Created by William Boles on 15/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

class AssetDownloadStack {
    
    fileprivate var array = [AssetDownloadItem]()
    
    // MARK: - Lifecycle
    
    func push(_ assetDownloadItem: AssetDownloadItem) {
        array.append(assetDownloadItem)
    }
    
    func pop() -> AssetDownloadItem? {
        guard let item = peek() else {
            return nil
        }
        
        array.removeLast()
        
        return item
    }
    
    func peek() -> AssetDownloadItem? {
        return array.last
    }
    
    func remove(_ assetDownloadItem: AssetDownloadItem) {
        guard let index = array.index(of: assetDownloadItem) else {
            return
        }
        
        array.remove(at: index)
    }
    
    // MARK: - Meta
    
    var count: Int {
        return array.count
    }
}

extension AssetDownloadStack: Sequence {
    
    // MARK: - Sequence
    
    func makeIterator() -> AssetDownloadStackIterator {
        return AssetDownloadStackIterator(self)
    }
}

struct AssetDownloadStackIterator: IteratorProtocol {
    
    private let assetDownloadStack: AssetDownloadStack
    private var index = 0
    
    // MARK: - Init
    
    init(_ assetDownloadStack: AssetDownloadStack) {
        self.assetDownloadStack = assetDownloadStack
        index = (assetDownloadStack.array.count - 1)
    }
    
    // MARK: - Next
    
    mutating func next() -> AssetDownloadItem? {
        guard index > 0 else {
            return nil
        }
        
        let assetDownloadItem = assetDownloadStack.array[index]
        index -= 1
        
        return assetDownloadItem
    }
}


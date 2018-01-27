//
//  Swift.swift
//  SmartMediaDownloader-Example
//
//  Created by William Boles on 27/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

struct Stack<T: Equatable> {
    
    fileprivate var array = [T]()
    
    // MARK: - Lifecycle
    
    mutating func push(_ element: T) {
        array.append(element)
    }
    
    mutating func pop() -> T? {
        return array.popLast()
    }
    
    var peek: T? {
        return array.last
    }
    
    mutating func remove(_ element: T) {
        guard let index = array.index(of: element) else {
            return
        }
        
        array.remove(at: index)
    }
    
    // MARK: - Meta
    
    var isEmpty: Bool {
        return array.isEmpty
    }
    
    var count: Int {
        return array.count
    }
}

extension Stack: Sequence {
    
    // MARK: - Sequence
    
    func makeIterator() -> StackIterator<T> {
        return StackIterator(self)
    }
}

struct StackIterator<T: Equatable>: IteratorProtocol {
    
    private let stack: Stack<T>
    private var index = 0
    
    // MARK: - Init
    
    init(_ stack: Stack<T>) {
        self.stack = stack
        index = (stack.array.count - 1)
    }
    
    // MARK: - Next
    
    mutating func next() -> T? {
        guard index > 0 else {
            return nil
        }
        
        let element = stack.array[index]
        index -= 1
        
        return element
    }
}

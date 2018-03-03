//
//  NSObject+Swizzle.swift
//  DownloadStack-ExampleTests
//
//  Created by William Boles on 01/02/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

extension NSObject {
    
    // MARK: - Instance
    
    class func swizzleMethodSelector(_ selector: Selector, withSelector: Selector) {
        let Class = self.self
        swizzleMethodSelector(selector, ofClass: Class, withSelector: withSelector, withClass: Class)
    }
    
    class func swizzleMethodSelector(_ selector: Selector, ofClass: AnyClass, withSelector: Selector, withClass: AnyClass) {
        let original = class_getInstanceMethod(ofClass, selector)
        let swizzled = class_getInstanceMethod(withClass, withSelector)
//        method_exchangeImplementations(original!, swizzled!)
        
        let didAddMethod = class_addMethod(ofClass, selector, method_getImplementation(swizzled!), method_getTypeEncoding(swizzled!))
        
        if didAddMethod {
            class_replaceMethod(ofClass, withSelector, method_getImplementation(original!), method_getTypeEncoding(original!))
        } else {
            method_exchangeImplementations(original!, swizzled!);
        }
    }
    
    // MARK: - Class
    
    class func swizzleClassMethodSelector(_ selector: Selector, withSelector: Selector) {
        let Class = self.self
        swizzleClassMethodSelector(selector, ofClass: Class, withSelector: withSelector, withClass: Class)
    }
    
    class func swizzleClassMethodSelector(_ selector: Selector, ofClass: AnyClass, withSelector: Selector, withClass: AnyClass) {
        let original = class_getClassMethod(ofClass, selector)
        let swizzled = class_getClassMethod(withClass, withSelector)
        method_exchangeImplementations(original!, swizzled!)
    }
}

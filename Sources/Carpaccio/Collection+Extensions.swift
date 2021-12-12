//
//  NSArray+Extensions.swift
//  Carpaccio
//
//  Created by Matias Piipari on 28/08/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation

// Inspired by http://moreindirection.blogspot.co.uk/2015/07/gcd-and-parallel-collections-in-swift.html
extension Swift.Collection where Index == Int {
    public func parallelMap<T>(_ transform: @escaping ((Iterator.Element) throws -> T)) throws -> [T] {
        return try self.parallelCompactMap(transform)
    }
    
    public func parallelCompactMap<T>(_ transform: @escaping ((Iterator.Element) throws -> T?)) throws -> [T] {
        guard !self.isEmpty else {
            return []
        }
        
        var result: [T?] = Array(repeating: nil, count: self.count)
        
        let group = DispatchGroup()
        let lock = DispatchQueue(label: "pcompactmap")
        var caughtError: Swift.Error? = nil

        DispatchQueue.concurrentPerform(iterations: self.count) { i in
            if caughtError != nil {
                return
            }
            
            do {
                let t = try transform(self[i])
                lock.async(group: group) {
                    result[i] = t
                }
            }
            catch {
                caughtError = error
            }
        }
        
        group.wait()
        
        if let error = caughtError {
            throw error
        }
        
        return result.compactMap { $0 }
    }
}

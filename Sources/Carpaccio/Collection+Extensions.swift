//
//  NSArray+Extensions.swift
//  Carpaccio
//
//  Created by Matias Piipari on 28/08/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation

// Inspired by http://moreindirection.blogspot.co.uk/2015/07/gcd-and-parallel-collections-in-swift.html
extension Swift.Collection where Self.Index == Int {
    public func parallelMap<T>(_ transform: @escaping ((Iterator.Element) throws -> T)) throws -> [T] {
        return try self.parallelCompactMap(transform)
    }
    
    public func parallelCompactMap<T>(_ transform: @escaping ((Iterator.Element) throws -> T?)) throws -> [T] {
        guard !self.isEmpty else {
            return []
        }
        
        var result: [(Int, T?)] = []
        
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
                    result += [(i, t)]
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
        
        return result.sorted { $0.0 < $1.0 }.compactMap { $0.1 }
    }
}

// Commented out, for now, due to unreliable operation: some elements might go missing from the result.
/*
// Inspired by http://moreindirection.blogspot.co.uk/2015/07/gcd-and-parallel-collections-in-swift.html
extension Swift.Sequence {
    public func parallelMap<T>(maxParallelism:Int? = nil, _
        transform: @escaping ((Iterator.Element) throws -> T)) throws -> [T]
    {
        return try self.parallelCompactMap(maxParallelism: maxParallelism, transform)
    }
    
    public func parallelCompactMap<T>(maxParallelism:Int? = nil, _ transform: @escaping ((Iterator.Element) throws -> T?)) throws -> [T]
    {
        if let maxParallelism = maxParallelism, maxParallelism == 1 {
            return try self.compactMap(transform)
        }
        
        var result: [(Int64, T)] = []
        let group = DispatchGroup()
        let lock = DispatchQueue(label: "pcompactmap")
        
        let parallelism:Int = {
            if let maxParallelism = maxParallelism {
                precondition(maxParallelism > 0)
                return maxParallelism
            }
            return ProcessInfo.processInfo.activeProcessorCount
        }()
        
        let semaphore = DispatchSemaphore(value: parallelism)
        var iterator = self.makeIterator()
        var index:Int64 = 0
        var caughtError: Swift.Error? = nil
        
        repeat {
            guard let item = iterator.next() else {
                break
            }
            semaphore.wait()
            DispatchQueue.global().async { [index] in
                do {
                    if let mappedElement = try transform(item) {
                        lock.async {
                            result += [(index, mappedElement)]
                        }
                    }
                }
                catch {
                    caughtError = error
                }
                semaphore.signal()
            }
            index += 1
        } while true
        
        group.wait()
        
        if let error = caughtError {
            throw error
        }

        return result.sorted { $0.0 < $1.0 }
                     .compactMap { $0.1 }
    }
}
 */

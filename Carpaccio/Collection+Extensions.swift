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
    public func parallelMap<T>(maxParallelism:Int? = nil,
                            _ transform: @escaping ((Iterator.Element) throws -> T)) throws -> [T]
    {
        return try self.parallelFlatMap(maxParallelism: maxParallelism, transform)
    }
    
    public func parallelFlatMap<T>(maxParallelism:Int? = nil,
                                _ transform: @escaping ((Iterator.Element) throws -> T?)) throws -> [T]
    {
        if let maxParallelism = maxParallelism, maxParallelism == 1 {
            return try self.flatMap(transform)
        }
        
        guard !self.isEmpty else {
            return []
        }
        
        var result: [(IntMax, [T])] = []
        
        let group = DispatchGroup()
        
        let lock = DispatchQueue(label: "pflatmap")
        
        let parallelism:Int = {
            if let maxParallelism = maxParallelism {
                precondition(maxParallelism > 0)
                return maxParallelism
            }
            
            return ProcessInfo.processInfo.activeProcessorCount
        }()
        
        // step can never be 0
        
        let count = self.count.toIntMax()
        let step = [1, count / IntMax(parallelism)].max()!
        
        var stepIndex:IntMax = 0
        var caughtError: Swift.Error? = nil

        repeat {
            var stepResult: [T] = []
            
            if let error = caughtError {
                throw error
            }
            
            DispatchQueue.global().async(group: group) { [capturedStepIndex = stepIndex] in
                if caughtError != nil {
                    return
                }
                
                for i in (capturedStepIndex * step) ..< ((capturedStepIndex + 1) * step) {
                    if caughtError != nil {
                        return
                    }
               
                    if i < count {
                        do {
                            if let mappedElement = try transform(self[Int(i)]) {
                                stepResult += [mappedElement]
                            }
                        }
                        catch {
                            caughtError = error
                        }
                    }
                }
                
                lock.async(group: group) {
                    result += [(capturedStepIndex, stepResult)]
                }
            }
            
            stepIndex += 1
        } while (stepIndex * step < count)
        
        group.wait()
        
        if let error = caughtError {
            throw error
        }
        
        return result.sorted { $0.0 < $1.0 }.flatMap { $0.1 }
    }
}


// Inspired by http://moreindirection.blogspot.co.uk/2015/07/gcd-and-parallel-collections-in-swift.html
extension Swift.Sequence {
    public func parallelMap<T>(maxParallelism:Int? = nil, _
        transform: @escaping ((Iterator.Element) throws -> T)) throws -> [T]
    {
        return try self.parallelFlatMap(maxParallelism: maxParallelism, transform)
    }
    
    public func parallelFlatMap<T>(maxParallelism:Int? = nil,
                                _ transform: @escaping ((Iterator.Element) throws -> T?)) throws -> [T]
    {
        if let maxParallelism = maxParallelism, maxParallelism == 1 {
            return try self.flatMap(transform)
        }
        
        var result: [(IntMax, T)] = []
        let group = DispatchGroup()
        let lock = DispatchQueue(label: "pflatmap")
        
        let parallelism:Int = {
            if let maxParallelism = maxParallelism {
                precondition(maxParallelism > 0)
                return maxParallelism
            }
            return ProcessInfo.processInfo.activeProcessorCount
        }()
        
        let semaphore = DispatchSemaphore(value: parallelism)
        var iterator = self.makeIterator()
        var index:IntMax = 0
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
                     .flatMap { $0.1 }
    }
}

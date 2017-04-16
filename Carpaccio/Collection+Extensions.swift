//
//  NSArray+Extensions.swift
//  Carpaccio
//
//  Created by Matias Piipari on 28/08/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation

// From http://moreindirection.blogspot.co.uk/2015/07/gcd-and-parallel-collections-in-swift.html
extension Swift.Collection where Self.Index == Int {
    public func parallelMap<T>(maxParallelism:Int? = nil,
                            _ transform: @escaping ((Iterator.Element) -> T)) -> [T]
    {
        return self.parallelFlatMap(maxParallelism: maxParallelism, transform)
    }
    
    public func parallelFlatMap<T>(maxParallelism:Int? = nil,
                                _ transform: @escaping ((Iterator.Element) -> T?)) -> [T]
    {
        if let maxParallelism = maxParallelism, maxParallelism == 1 {
            return self.flatMap(transform)
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
        repeat {
            let capturedStepIndex = stepIndex
            
            var stepResult: [T] = []
            
            DispatchQueue.global().async(group: group) {
                for i in (capturedStepIndex * step) ..< ((capturedStepIndex + 1) * step) {
                    if i < count {
                        if let mappedElement = transform(self[Int(i)]) {
                            stepResult += [mappedElement]
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
        
        return result.sorted { $0.0 < $1.0 }.flatMap { $0.1 }
    }
}


extension Swift.Sequence {
    public func parallelMap<T>(maxParallelism:Int? = nil, _ transform: @escaping ((Iterator.Element) -> T)) -> [T]
    {
        return self.parallelFlatMap(maxParallelism: maxParallelism, transform)
    }
    
    public func parallelFlatMap<T>(maxParallelism:Int? = nil,
                                _ transform: @escaping ((Iterator.Element) -> T?)) -> [T]
    {
        if let maxParallelism = maxParallelism, maxParallelism == 1 {
            return self.flatMap(transform)
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
        
        repeat {
            guard let item = iterator.next() else { break }
            semaphore.wait()
            
            DispatchQueue.global().async {
                if let mappedElement = transform(item) {
                    lock.async {
                        result += [(index, mappedElement)]
                    }
                }
                semaphore.signal()
            }
            index += 1
        } while true
        
        group.wait()
        
        return result.sorted { $0.0 < $1.0 }.flatMap { $0.1 }
    }
}

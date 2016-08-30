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
    public func pmap<T>(maxParallelism:Int? = nil, _ transform: ((Iterator.Element) -> T)) -> [T] {
        if let maxParallelism = maxParallelism, maxParallelism == 1 {
            return self.map(transform)
        }
        
        guard !self.isEmpty else {
            return []
        }
        
        var result: [(IntMax, [T])] = []
        
        let group = DispatchGroup()
        
        let lock = DispatchQueue(label: "pmap")
        
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
                        let mappedElement = transform(self[Int(i)])
                        stepResult += [mappedElement]
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

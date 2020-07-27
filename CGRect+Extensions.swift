//
//  CGRect+Extensions.swift
//  Carpaccio-OSX
//
//  Created by Matias Piipari on 14/12/2018.
//  Copyright © 2018 Matias Piipari & Co. All rights reserved.
//

import Foundation

public extension Array where Iterator.Element == CGRect {
    var union: CGRect {
        if self.count == 0 {
            return CGRect.zero
        }
        var u = self.first!
        for i in 1 ..< self.count {
            u = u.union(self[i])
        }
        return u
    }
}

//
//  Utility.swift
//  Carpaccio
//
//  Created by Markus Piipari on 30/07/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation
import QuartzCore

extension CGSize
{
    public var aspectRatio: CGFloat
        {
        get
        {
            if self.width == 0.0 {
                return 0.0
            }
            
            if self.height == 0.0 {
                return CGFloat.infinity
            }
            
            return self.width / self.height
        }
    }
    
    public func proportionalWidth(forHeight height: CGFloat) -> CGFloat
    {
        return height * self.aspectRatio
    }
    
    public func proportionalHeight(forWidth width: CGFloat) -> CGFloat
    {
        return width / self.aspectRatio
    }
    
    public func distance(to: CGSize) -> CGFloat {
        let xDist = to.width - self.width
        let yDist = to.width - self.width
        return sqrt((xDist * xDist) + (yDist * yDist))
    }
}


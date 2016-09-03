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
    public var widthToHeightRatio: CGFloat
        {
        get
        {
            if self.width == 0.0 {
                return 0.0
            }
            
            if self.height == 0.0 {
                return CGFloat.infinity
            }
            
            return round(self.width) / round(self.height)
        }
    }
    
    public func width(forHeight height: CGFloat) -> CGFloat
    {
        return height * self.widthToHeightRatio
    }
    
    public func height(forWidth width: CGFloat) -> CGFloat
    {
        return width / self.widthToHeightRatio
    }
}


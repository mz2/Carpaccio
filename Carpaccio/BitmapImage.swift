//
//  BitmapImage.swift
//  Carpaccio
//
//  Created by Matias Piipari on 03/09/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation
import QuartzCore

public protocol BitmapImage:NSObjectProtocol {
    func name() -> String?
    
    var size: CGSize { get }
    
    func scaled(height: CGFloat, screenScaleFactor: CGFloat) -> BitmapImage
}

public extension BitmapImage {
    public var bounds: CGRect
        {
        get {
            return CGRect(x: 0.0, y: 0.0, width: self.size.width, height: self.size.height)
        }
    }
    
    public var widthToHeightRatio: CGFloat
        {
        get {
            return self.size.widthToHeightRatio
        }
    }
    
    public func width(forHeight height: CGFloat) -> CGFloat
    {
        return self.size.width(forHeight: height)
    }
    
    public func height(forWidth width: CGFloat) -> CGFloat
    {
        return self.size.height(forWidth: width)
    }
}

//
//  BitmapImage.swift
//  Carpaccio
//
//  Created by Matias Piipari on 03/09/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation
import QuartzCore

public protocol BitmapImage: NSObjectProtocol {
    var nameString: String? { get }
    
    var size: CGSize { get }
    
    func scaled(height: CGFloat, screenScaleFactor: CGFloat) -> BitmapImage
    
    var cgImage:CGImage? { get }
}

public extension BitmapImage {
    var bounds: CGRect {
        get {
            return CGRect(x: 0.0, y: 0.0, width: self.size.width, height: self.size.height)
        }
    }
    
    var aspectRatio: CGFloat
        {
        get {
            return self.size.aspectRatio
        }
    } 
    
    func proportionalWidth(forHeight height: CGFloat, precision: PrecisionScheme) -> CGFloat {
        return self.size.proportionalWidth(forHeight: height, precision: precision)
    }
    
    func proportionalHeight(forWidth width: CGFloat, precision: PrecisionScheme) -> CGFloat {
        return self.size.proportionalHeight(forWidth: width, precision: precision)
    }
}

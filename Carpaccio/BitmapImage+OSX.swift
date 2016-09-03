//
//  BitmapImage+OSX.swift
//  Carpaccio
//
//  Created by Matias Piipari on 03/09/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import AppKit

extension NSImage:BitmapImage {
    
    public var cgImage:CGImage? {
        return self.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}

extension BitmapImage {
    
    public var nsImage:NSImage {
        return self as! NSImage
    }
    
}

extension NSImage {
    
    // this is a BitmapImage protocol method
    public func scaled(height: CGFloat, screenScaleFactor: CGFloat) -> BitmapImage
    {
        let widthToHeightRatio = self.size.width / self.size.height
        let pixelHeight = height * screenScaleFactor
        let pixelWidth = round(widthToHeightRatio * pixelHeight)
        
        let scaledBitmapImage = BitmapImageUtility.image(sized: CGSize(width: pixelWidth, height: pixelHeight))
        
        let scaledImage = scaledBitmapImage as! NSImage
        
        scaledImage.cacheMode = .never
        
        scaledImage.lockFocus()
        
        NSGraphicsContext.current()?.imageInterpolation = .default
        
        self.draw(in: CGRect(x: 0.0,
                             y: 0.0,
                             width: pixelWidth,
                             height: pixelHeight),
                  from: CGRect(x: 0.0,
                               y: 0.0,
                               width: self.size.width,
                               height: self.size.height),
                  operation: .copy,
                  fraction: 1.0)
        scaledImage.unlockFocus()
        
        return scaledImage
    }
    
}

struct BitmapImageUtility {
    
    static func image(named string:String) -> BitmapImage? {
        return NSImage(named: string)
    }
    
    static func image(sized size: CGSize) -> BitmapImage {
        return NSImage(size: size)
    }
    
    static func image(cgImage: CGImage, size: CGSize) -> BitmapImage {
        return NSImage(cgImage: cgImage, size: size)
    }
    
    static func image(ciImage image: CIImage) -> BitmapImage? {
        guard let ciContext = NSGraphicsContext.current()?.ciContext else {
            return nil
        }
        
        let returnedImage = self.image(sized: image.extent.size) as! NSImage
        returnedImage.cacheMode = .never
        returnedImage.lockFocus()
        ciContext.draw(image, in: image.extent, from: image.extent)
        returnedImage.unlockFocus()
        
        return returnedImage
    }

}

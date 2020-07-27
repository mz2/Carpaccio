//
//  BitmapImage+OSX.swift
//  Carpaccio
//
//  Created by Matias Piipari on 03/09/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

#if os(macOS)
import AppKit

extension NSImage: BitmapImage {
    public var nameString: String? {
        return {
            if let name = self.name() {
                return name
            }
            return nil
        }()
    }

    public var cgImage: CGImage? {
        return self.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    public var bestAvailableCGImage: CGImage? {
        guard let rep = bestRepresentation(for: NSRect.infinite, context: nil, hints: nil) else {
            return nil
        }
        var r = NSRect.infinite
        return rep.cgImage(forProposedRect: &r, context: nil, hints: nil)
    }
}

extension BitmapImage {
    public var nsImage:NSImage {
        return self as! NSImage
    }
}

extension NSImage {
    // this is a BitmapImage protocol method
    public func scaled(height: CGFloat, screenScaleFactor: CGFloat) -> BitmapImage {
        let aspectRatio = self.size.width / self.size.height
        let pixelHeight = height * screenScaleFactor
        let pixelWidth = round(aspectRatio * pixelHeight)
        
        let scaledBitmapImage = BitmapImageUtility.image(sized: CGSize(width: pixelWidth, height: pixelHeight))
        
        let scaledImage = scaledBitmapImage as! NSImage
        
        scaledImage.cacheMode = .never
        
        scaledImage.lockFocus()
        
        NSGraphicsContext.current?.imageInterpolation = .default
        
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

public struct BitmapImageUtility {
    
    public static func image(named string:String) -> BitmapImage? {
        return NSImage(named: string)
    }
    
    public static func image(named imageName: String, bundle: Bundle) -> BitmapImage? {
        return bundle.image(forResource: imageName)
    }
    
    public static func image(sized size: CGSize) -> BitmapImage {
        return NSImage(size: size)
    }
    
    public static func image(cgImage: CGImage, size: CGSize? = nil) -> BitmapImage {
        return NSImage(cgImage: cgImage, size: size ?? .zero)
    }
    
    public static func image(ciImage: CIImage) -> BitmapImage?
    {
        let nsImage = self.image(sized: ciImage.extent.size) as! NSImage
        let rep = NSCIImageRep(ciImage: ciImage)
        nsImage.addRepresentation(rep)
        return nsImage
    }

    public static func image(_ overlay: BitmapImage, overlayedOn background: BitmapImage) -> NSImage {
        let newImage = BitmapImageUtility.image(sized: background.size) as! NSImage
        
        newImage.lockFocus()
        
        var newImageRect = CGRect.zero
        newImageRect.size = newImage.size
        
        (background as! NSImage).draw(in: newImageRect)
        (overlay as! NSImage).draw(in: newImageRect)
        
        newImage.unlockFocus()
        
        return newImage
    }
}

#endif
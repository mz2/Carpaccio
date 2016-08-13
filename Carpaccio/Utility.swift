//
//  Utility.swift
//  Carpaccio
//
//  Created by Markus Piipari on 30/07/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//


import Cocoa


public extension NSImage
{
    public var bounds: NSRect
        {
        get {
            return NSRect(x: 0.0, y: 0.0, width: self.size.width, height: self.size.height)
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

extension NSSize
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

public func scale(presentableImage inputImage: NSImage, height: CGFloat, screenScaleFactor: CGFloat) -> NSImage
{
    let widthToHeightRatio = inputImage.size.width / inputImage.size.height
    let pixelHeight = height * screenScaleFactor
    let pixelWidth = round(widthToHeightRatio * pixelHeight)
    
    let scaledImage = NSImage(size: NSSize(width: pixelWidth, height: pixelHeight))
    scaledImage.cacheMode = .Never
    
    scaledImage.lockFocus()
    NSGraphicsContext.currentContext()?.imageInterpolation = .Default
    inputImage.drawInRect(NSRect(x: 0.0, y: 0.0, width: pixelWidth, height: pixelHeight), fromRect: NSRect(x: 0.0, y: 0.0, width: inputImage.size.width, height: inputImage.size.height), operation: .CompositeCopy, fraction: 1.0)
    scaledImage.unlockFocus()
    
    return scaledImage
}
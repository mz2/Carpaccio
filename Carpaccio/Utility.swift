//
//  Utility.swift
//  Carpaccio
//
//  Created by Markus Piipari on 30/07/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//


import Cocoa


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
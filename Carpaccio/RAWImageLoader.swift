//
//  RAWImageLoader.swift
//  Carpaccio
//
//  Created by Markus Piipari on 31/07/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//


import CoreGraphics
import CoreImage


public enum RAWImageLoaderError: ErrorType
{
    case FailedToExtractImageMetadata(message: String)
    case FailedToLoadThumbnailImage(message: String)
    case FailedToLoadFullSizeImage(message: String)
}


public enum ImageLoadingThumbnailScheme: Int
{
    case AlwaysDecodeFullImage
    case DecodeFullImageIfThumbnailTooSmall
    case DecodeFullImageIfThumbnailMissing
}


public class RAWImageLoader: ImageLoaderProtocol
{
    public let imageURL: NSURL
    public let thumbnailScheme: ImageLoadingThumbnailScheme
    
    init(imageURL: NSURL, thumbnailScheme: ImageLoadingThumbnailScheme)
    {
        self.imageURL = imageURL
        self.thumbnailScheme = thumbnailScheme
    }
    
    private var imageSource: CGImageSource? {
        get
        {
            // We intentionally don't store the image source, to not gob up resources, but rather open it anew each time
            let options: CFDictionary = [String(kCGImageSourceShouldCache): false, String(kCGImageSourceShouldAllowFloat): true]
            let imageSource = CGImageSourceCreateWithURL(imageURL, options)
            return imageSource
        }
    }
    
    public lazy var imageMetadata: ImageMetadata? = {
        
        guard let imageSource = self.imageSource else {
            return nil
        }
        
        //self.dumpAllImageMetadata(imageSource)
        
        let properties = NSDictionary(dictionary: CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)!)
        
        var aperture: Double? = nil, focalLength: Double? = nil, focalLength35mm: Double? = nil, ISO: Double? = nil, shutterSpeed: Double? = nil
        var width: CGFloat? = nil, height: CGFloat? = nil
        
        // Examine EXIF metadata
        if let EXIF = properties[kCGImagePropertyExifDictionary as! NSString] as? NSDictionary
        {
            aperture = EXIF[kCGImagePropertyExifFNumber as! NSString]?.doubleValue
            focalLength = EXIF[kCGImagePropertyExifFocalLength as! NSString]?.doubleValue
            focalLength35mm = EXIF[kCGImagePropertyExifFocalLenIn35mmFilm as! NSString]?.doubleValue
            
            if let ISOs = EXIF[kCGImagePropertyExifISOSpeedRatings as! NSString]
            {
                let ISOArray = NSArray(array: ISOs as! CFArray)
                if ISOArray.count > 0 {
                    ISO = ISOArray[0].doubleValue
                }
            }
            
            shutterSpeed = EXIF[kCGImagePropertyExifExposureTime as! NSString]?.doubleValue
            
            if let w = EXIF[kCGImagePropertyExifPixelXDimension as! NSString]?.doubleValue {
                width = CGFloat(w)
            }
            if let h = EXIF[kCGImagePropertyExifPixelYDimension as! NSString]?.doubleValue {
                height = CGFloat(h)
            }
        }
        
        // Examine TIFF metadata
        var cameraMaker: String? = nil, cameraModel: String? = nil, orientation: CGImagePropertyOrientation? = nil
        
        if let TIFF = properties[kCGImagePropertyTIFFDictionary as! NSString] as? NSDictionary
        {
            cameraMaker = TIFF[kCGImagePropertyTIFFMake as! NSString] as? String
            cameraModel = TIFF[kCGImagePropertyTIFFModel as! NSString] as? String
            orientation = CGImagePropertyOrientation(rawValue: TIFF[kCGImagePropertyTIFFOrientation as! NSString]?.unsignedIntValue ?? 1)
        }
        
        /*
         If image dimension didn't appear in metadata (can happen with some RAW files like Nikon NEFs), take one more step:
         open the actual image. This thankfully doesn't appear to immediately load image data.
         */
        if width == nil || height == nil
        {
            let options: CFDictionary = [String(kCGImageSourceShouldCache): false]
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options)
            width = CGFloat(CGImageGetWidth(image))
            height = CGFloat(CGImageGetHeight(image))
        }
        
        let metadata = ImageMetadata(nativeSize: NSSize(width: width!, height: height!), nativeOrientation: orientation ?? .Up, aperture: aperture, focalLength: focalLength, ISO: ISO, focalLength35mmEquivalent: focalLength35mm, shutterSpeed: shutterSpeed, cameraMaker: cameraMaker, cameraModel: cameraModel)
        return metadata
    }()
    
    private func dumpAllImageMetadata(imageSource: CGImageSource)
    {
        let metadata = CGImageSourceCopyMetadataAtIndex(imageSource, 0, nil)
        let options: [String: AnyObject] = [String(kCGImageMetadataEnumerateRecursively): true as CFNumber]
        var results = [String: AnyObject]()

        CGImageMetadataEnumerateTagsUsingBlock(metadata!, nil, options) { (path: CFString, tag: CGImageMetadataTag) -> Bool in
            
            if let value = CGImageMetadataTagCopyValue(tag) {
                results[path as String] = value
            }
            else {
                results[path as String] = "??"
            }
            return true
        }
        
        print("---- All metadata for \(self.imageURL.path!): ----")
        
        for key in results.keys.sort()
        {
            print("    \(key) = \(results[key]!)")
        }
        
        print("----")
    }
    
    public func loadImageMetadata(handler: ImageMetadataHandler, errorHandler: ImageLoadingErrorHandler)
    {
        guard let imageSource = self.imageSource else {
            precondition(false)
            return
        }
        
        if let metadata = self.imageMetadata {
            handler(metadata: metadata)
        }
        else {
            errorHandler(error: RAWImageLoaderError.FailedToExtractImageMetadata(message: "Failed to read image properties for \(self.imageURL.path!)"))
        }
    }
    
    private func _loadThumbnailImage(maximumPixelDimensions maximumSize: NSSize?) -> CGImage?
    {
        guard let source = self.imageSource else {
            precondition(false)
            return nil
        }
        
        let maxPixelSize: CGFloat? = maximumSize?.maximumPixelSize(forImageSize: self.imageMetadata!.size)
        var createFromFullImage: Bool = false
        
        if self.thumbnailScheme == .AlwaysDecodeFullImage {
            createFromFullImage = true
        }
        
        // If thumbnail dimensions are too small for current configuration, create from full image
        /*if self.thumbnailScheme == .DecodeFullImageIfThumbnailTooSmall && maximumSize != nil
        {
            let options: [String: AnyObject] = [String(kCGImageSourceCreateThumbnailFromImageIfAbsent): false]
            let t = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
            
            let w = CGImageGetWidth(t)
            let h = CGImageGetHeight(t)
            let m = Int(round(maxPixelSize!))
            
            createFromFullImage = w < m && h < m
                
            if createFromFullImage {
                print("Will decode thumbnail from full image for \(self.imageURL.lastPathComponent!), would be too small at \(NSSize(width: w, height: h)) for requested pixel dimensions \(maximumSize!) yeilding max pixel size \(Int(round(maxPixelSize!)))")
            }
            else {
                print("Will use pre-rendered thumbail for \(self.imageURL.lastPathComponent!), is big enough at \(NSSize(width: w, height: h)) for requested pixel dimensions \(maximumSize!) yeilding max pixel size \(Int(round(maxPixelSize!)))")
            }
        }*/
        
        var options: [String: AnyObject] = [String(kCGImageSourceCreateThumbnailWithTransform): true, String(createFromFullImage ? kCGImageSourceCreateThumbnailFromImageAlways : kCGImageSourceCreateThumbnailFromImageIfAbsent): true]
        
        if let sz = maxPixelSize {
            options[String(kCGImageSourceThumbnailMaxPixelSize)] = Int(round(sz))
        }
        
        let thumbnailImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        return thumbnailImage
    }
    
    public func loadThumbnailImage(maximumPixelDimensions maxPixelSize: NSSize?, handler: PresentableImageHandler, errorHandler: ImageLoadingErrorHandler)
    {
        guard let source = self.imageSource else {
            precondition(false)
            return
        }
        
        if let thumbnailImage = _loadThumbnailImage(maximumPixelDimensions: maxPixelSize)
        {
            handler(image: NSImage(CGImage: thumbnailImage, size: NSZeroSize), metadata: self.imageMetadata!)
        }
        else {
            errorHandler(error: RAWImageLoaderError.FailedToLoadThumbnailImage(message: "Failed to load thumbnail image from \(self.imageURL.path!)"))
        }
    }
    
    public func loadFullSizeImage(maximumPixelDimensions maxPixelSize: NSSize?, handler: PresentableImageHandler, errorHandler: ImageLoadingErrorHandler)
    {
        guard let metadata = self.imageMetadata else {
            errorHandler(error: RAWImageLoaderError.FailedToExtractImageMetadata(message: "Failed to read properties of \(self.imageURL.path!) to load full-size image")); return
        }
        
        let scaleFactor: Double
        
        if let sz = maxPixelSize
        {
            let imageSize = metadata.size
            let height = sz.scaledHeight(forImageSize: imageSize)
            scaleFactor = Double(height / imageSize.height)
        }
        else {
            scaleFactor = 1.0
        }
        
        // NOTE: Having the draft mode option set to `true` appears to be crucial to performance, with a difference of 0.3s vs. 2.5s per image on this iMac 5K, for instance.
        // The quality is still quite excellent for displaying scaled-down presentations in a collection view, subjectively better than what you get from LibRAW with the half-size option.
        let options: [NSObject: AnyObject] = [kCIInputScaleFactorKey: scaleFactor, kCIInputAllowDraftModeKey: true, kCIInputBoostShadowAmountKey: NSNumber(float: 1.0)]
        let RAWFilter = CIFilter(imageURL: self.imageURL, options: options)
        
        if let bakedImage = RAWFilter.outputImage
        {
            var image = NSImage(size: bakedImage.extent.size)
            image.cacheMode = .Never
            image.lockFocus()
            NSGraphicsContext.currentContext()?.CIContext?.drawImage(bakedImage, inRect: bakedImage.extent, fromRect: bakedImage.extent)
            image.unlockFocus()
            
            handler(image: image, metadata: ImageMetadata(nativeSize: image.size))
        }
        else {
            errorHandler(error: RAWImageLoaderError.FailedToLoadFullSizeImage(message: "Failed to load full-size RAW image \(self.imageURL.path!)"))
        }
    }
}

extension NSSize
{
    init(constrainWidth w: CGFloat)
    {
        self.width = w
        self.height = CGFloat.max
    }
    
    init(constrainHeight h: CGFloat)
    {
        self.width = CGFloat.max
        self.height = h
    }
    
    /** Assuming this NSSize value describes desired maximum width and/or height of a scaled output image, return appropriate value for the `kCGImageSourceThumbnailMaxPixelSize` option. */
    func maximumPixelSize(forImageSize imageSize: NSSize) -> CGFloat
    {
        let widthIsUnconstrained = self.width > imageSize.width
        let heightIsUnconstrained = self.height > imageSize.height
        let ratio = imageSize.widthToHeightRatio
        
        if widthIsUnconstrained && heightIsUnconstrained
        {
            if ratio > 1.0 {
                return imageSize.width
            }
            return imageSize.height
        }
        else if widthIsUnconstrained {
            if ratio > 1.0 {
                return imageSize.width(forHeight: self.height)
            }
            return self.height
        }
        else if heightIsUnconstrained {
            if ratio > 1.0 {
                return self.width
            }
            return imageSize.height(forWidth: self.width)
        }
        
        return min(self.width, self.height)
    }
    
    func scaledHeight(forImageSize imageSize: NSSize) -> CGFloat
    {
        return min(imageSize.height, self.height)
    }
}
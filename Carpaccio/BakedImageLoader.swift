//
//  BakedImageLoader.swift
//  Carpaccio
//
//  Created by Markus Piipari on 27/07/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//


import Foundation
import ImageIO


public enum BakedImageLoaderError: ErrorType
{
    case FailedToExtractImageMetadata(message: String)
    case FailedToLoadThumbnailImage(message: String)
    case FailedToLoadFullSizeImage(message: String)
}


public class BakedImageLoader: ImageLoaderProtocol
{
    public let imageURL: NSURL
    
    private let alwaysCreateThumbnailFromFullImage = true
    //private var imageSource: CGImageSource?
    //private var image: CGImage?
    private var imageMetadata: ImageMetadata?
    
    init(imageURL: NSURL)
    {
        self.imageURL = imageURL
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
    
    public func extractImageMetadata(handler: ImageMetadataHandler, errorHandler: ImageLoadingErrorHandler)
    {
        guard let imageSource = self.imageSource else {
            precondition(false)
            return
        }
        
        let properties = NSDictionary(dictionary: CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)!)
        
        if let EXIF = properties[kCGImagePropertyExifDictionary as! NSString] as? NSDictionary,
           let TIFF = properties[kCGImagePropertyTIFFDictionary as! NSString] as? NSDictionary
        {
            //let EXIF = NSDictionary(dictionary: EXIFDictionary as! CFDictionary)
            let cameraMaker = TIFF[kCGImagePropertyTIFFMake as! NSString] as? String
            let cameraModel = TIFF[kCGImagePropertyTIFFModel as! NSString] as? String
            
            let aperture = EXIF[kCGImagePropertyExifApertureValue as! NSString]?.doubleValue ?? 0.0
            let focalLength = EXIF[kCGImagePropertyExifFocalLength as! NSString]?.doubleValue ?? 0.0
            let focalLength35mm = EXIF[kCGImagePropertyExifFocalLenIn35mmFilm as! NSString]?.doubleValue ?? 0.0
            let height = CGFloat(EXIF[kCGImagePropertyExifPixelYDimension as! NSString]?.doubleValue ?? 0.0)
            
            var ISO = 0.0
            if let ISOs = EXIF[kCGImagePropertyExifISOSpeedRatings as! NSString]
            {
                let ISOArray = NSArray(array: ISOs as! CFArray)
                if ISOArray.count > 0 {
                    ISO = ISOArray[0].doubleValue
                }
            }
            
            let shutterSpeed = EXIF[kCGImagePropertyExifExposureTime as! NSString]?.doubleValue ?? 0.0
            let width = CGFloat(EXIF[kCGImagePropertyExifPixelXDimension as! NSString]?.doubleValue ?? 0.0)
            
            let metadata = ImageMetadata(nativeSize: NSSize(width: width, height: height), aperture: aperture, focalLength: focalLength, ISO: ISO, focalLength35mmEquivalent: focalLength35mm, shutterSpeed: shutterSpeed, cameraMaker: cameraMaker, cameraModel: cameraModel)
            
            self.imageMetadata = metadata
            
            handler(metadata: metadata)
        }
        else {
            errorHandler(error: BakedImageLoaderError.FailedToExtractImageMetadata(message: "Failed to read image properties for \(self.imageURL.path!)"))
        }
    }
    
    private func _loadThumbnailImage(maximumPixelDimensions maxPixelSize: NSSize?, alwaysUseFullImage: Bool? = nil) -> CGImage?
    {
        guard let source = self.imageSource else {
            precondition(false)
            return nil
        }
        
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        let createFromFullImage = alwaysUseFullImage ?? self.alwaysCreateThumbnailFromFullImage
        
        var options: [String: AnyObject] = [String(kCGImageSourceCreateThumbnailWithTransform): true,
                                            String(createFromFullImage ? kCGImageSourceCreateThumbnailFromImageAlways : kCGImageSourceCreateThumbnailFromImageIfAbsent): true]
        
        if let sz = maxPixelSize {
            options[String(kCGImageSourceThumbnailMaxPixelSize)] = maxPixelSize?.maximumPixelSize(forImageSize: self.imageMetadata!.size)
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
            errorHandler(error: BakedImageLoaderError.FailedToLoadThumbnailImage(message: "Failed to load thumbnail image from \(self.imageURL.path!)"))
        }
    }
    
    public func loadFullSizeImage(maximumPixelDimensions maxPixelSize: NSSize?, handler: PresentableImageHandler, errorHandler: ImageLoadingErrorHandler)
    {
        guard let source = self.imageSource else {
            precondition(false)
            return
        }
        
        let image: CGImage?
        
        if let sz = maxPixelSize {
            image = _loadThumbnailImage(maximumPixelDimensions: maxPixelSize)
        }
        else {
            image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        
        if let image = image
        {
            handler(image: NSImage(CGImage: image, size: NSZeroSize), metadata: self.imageMetadata!)
        }
        else {
            errorHandler(error: BakedImageLoaderError.FailedToLoadThumbnailImage(message: "Failed to load full-size image from \(self.imageURL.path!)"))
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
        let imageWidthToHeightRatio = abs(imageSize.width / imageSize.height)
        
        if imageWidthToHeightRatio > 1.0 {
            return min(imageSize.width, self.width)
        }
        
        return min(imageSize.height, self.height)
    }
    
    func scaledHeight(forImageSize imageSize: NSSize) -> CGFloat
    {
        return min(imageSize.height, self.height)
    }

}

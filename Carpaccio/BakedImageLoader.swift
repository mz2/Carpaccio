
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
    
    private let alwaysCreateThumbnailFromFullImage = false
    private var imageSource: CGImageSource?
    //private var image: CGImage?
    private var imageMetadata: ImageMetadata?
    
    init(imageURL: NSURL)
    {
        self.imageURL = imageURL
        
        let options: CFDictionary = [String(kCGImageSourceShouldCache): false, String(kCGImageSourceShouldAllowFloat): true]
        self.imageSource = CGImageSourceCreateWithURL(imageURL, options)
    }
    
    public func extractImageMetadata(handler: ImageMetadataHandler, errorHandler: ImageLoadingErrorHandler)
    {
        if let imageSource = self.imageSource,
            let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil),
            let EXIFDictionary = NSDictionary(dictionary: properties)[kCGImagePropertyExifDictionary as! NSString]
        {
            let EXIF = NSDictionary(dictionary: EXIFDictionary as! CFDictionary)
            
            let aperture = EXIF[kCGImagePropertyExifApertureValue as! NSString]?.doubleValue ?? 0.0
            let focalLength = EXIF[kCGImagePropertyExifFocalLength as! NSString]?.doubleValue ?? 0.0
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
            
            let metadata = ImageMetadata(size: NSSize(width: width, height: height), aperture: aperture, focalLength: focalLength, ISO: ISO, shutterSpeed: shutterSpeed)
            
            self.imageMetadata = metadata
            
            handler(metadata: metadata)
        }
        else {
            errorHandler(error: BakedImageLoaderError.FailedToExtractImageMetadata(message: "Failed to read image properties for \(self.imageURL.path!)"))
        }
    }
    
    public func loadThumbnailImage(handler: PresentableImageHandler, errorHandler: ImageLoadingErrorHandler)
    {
        guard let source = self.imageSource else {
            precondition(false, "Ooops")
            return
        }
        
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        
        let options = [String(kCGImageSourceCreateThumbnailWithTransform): true, String(self.alwaysCreateThumbnailFromFullImage ? kCGImageSourceCreateThumbnailFromImageAlways : kCGImageSourceCreateThumbnailFromImageIfAbsent): true]//, String(kCGImageSourceThumbnailMaxPixelSize): 500]
        
        if let thumbnailImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        {
            handler(image: NSImage(CGImage: thumbnailImage, size: NSZeroSize), metadata: self.imageMetadata!)
        }
        else {
            errorHandler(error: BakedImageLoaderError.FailedToLoadThumbnailImage(message: "Failed to load thumbnail image from \(self.imageURL.path!)"))
        }
    }
    
    public func loadFullSizeImage(handler: PresentableImageHandler, errorHandler: ImageLoadingErrorHandler)
    {
        guard let source = self.imageSource else {
            precondition(false, "Öööps")
            return
        }
        
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        
        if let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        {
            handler(image: NSImage(CGImage: image, size: NSZeroSize), metadata: self.imageMetadata!)
        }
        else {
            errorHandler(error: BakedImageLoaderError.FailedToLoadThumbnailImage(message: "Failed to load full-size image from \(self.imageURL.path!)"))
        }
    }
}

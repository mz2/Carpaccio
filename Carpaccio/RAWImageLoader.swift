//
//  RAWImageLoader.swift
//  Carpaccio
//
//  Created by Markus Piipari on 31/07/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation

import CoreGraphics
import CoreImage
import ImageIO

public enum RAWImageLoaderError: Swift.Error
{
    case failedToExtractImageMetadata(message: String)
    case failedToLoadThumbnailImage(message: String)
    case failedToLoadFullSizeImage(message: String)
}

public class RAWImageLoader: ImageLoaderProtocol
{    
    public enum ThumbnailScheme: Int
    {
        case decodeFullImage
        case fullImageWhenTooSmallThumbnail
        case fullImageWhenThumbnailMissing
    }
    
    public let imageURL: URL
    public let cachedImageURL: URL? = nil // For now, we don't implement a disk cache for images loaded by RAWImageLoader
    public let thumbnailScheme: ThumbnailScheme
    
    // See ImageMetadata.timestamp for known caveats about EXIF/TIFF
    // date metadata, as interpreted by this date formatter.
    private static let EXIFDateFormatter: DateFormatter =
    {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()
    
    init(imageURL: URL, thumbnailScheme: ThumbnailScheme)
    {
        self.imageURL = imageURL
        self.thumbnailScheme = thumbnailScheme
    }
    
    private var imageSource: CGImageSource?
    {
        // We intentionally don't store the image source, to not gob up resources, but rather open it anew each time
        let options = [String(kCGImageSourceShouldCache): false, String(kCGImageSourceShouldAllowFloat): true] as NSDictionary as CFDictionary
        let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, options)
        return imageSource
    }
    
    public lazy var imageMetadata: ImageMetadata? = {

        guard let imageSource = self.imageSource else {
            return nil
        }
        
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) else {
            return nil
        }
        
        let properties = NSDictionary(dictionary: imageProperties)
        
        var fNumber: Double? = nil, focalLength: Double? = nil, focalLength35mm: Double? = nil, ISO: Double? = nil, shutterSpeed: Double? = nil
        var colorSpace: CGColorSpace? = nil
        var width: CGFloat? = nil, height: CGFloat? = nil
        var timestamp: Date? = nil
        
        // Examine EXIF metadata
        if let EXIF = properties[kCGImagePropertyExifDictionary as String] as? NSDictionary
        {
            fNumber = (EXIF[kCGImagePropertyExifFNumber as String] as? NSNumber)?.doubleValue
            
            if let colorSpaceName = EXIF[kCGImagePropertyExifColorSpace] as? NSString {
                colorSpace = CGColorSpace(name: colorSpaceName)
            }
            
            focalLength = (EXIF[kCGImagePropertyExifFocalLength as String] as? NSNumber)?.doubleValue
            focalLength35mm = (EXIF[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? NSNumber)?.doubleValue
            
            if let ISOs = EXIF[kCGImagePropertyExifISOSpeedRatings as String]
            {
                let ISOArray = NSArray(array: ISOs as! CFArray)
                if ISOArray.count > 0 {
                    ISO = (ISOArray[0] as? NSNumber)?.doubleValue
                }
            }
            
            shutterSpeed = (EXIF[kCGImagePropertyExifExposureTime as String] as? NSNumber)?.doubleValue
            
            if let w = (EXIF[kCGImagePropertyExifPixelXDimension as String] as? NSNumber)?.doubleValue {
                width = CGFloat(w)
            }
            if let h = (EXIF[kCGImagePropertyExifPixelYDimension as String] as? NSNumber)?.doubleValue {
                height = CGFloat(h)
            }
            
            if let originalDateString = (EXIF[kCGImagePropertyExifDateTimeOriginal as String] as? String) {
                timestamp = EXIFDateFormatter.date(from: originalDateString)
            }
        }
        
        // Examine TIFF metadata
        var cameraMaker: String? = nil, cameraModel: String? = nil, orientation: CGImagePropertyOrientation? = nil
        
        if let TIFF = properties[kCGImagePropertyTIFFDictionary as String] as? NSDictionary
        {
            cameraMaker = TIFF[kCGImagePropertyTIFFMake as String] as? String
            cameraModel = TIFF[kCGImagePropertyTIFFModel as String] as? String
            orientation = CGImagePropertyOrientation(rawValue: (TIFF[kCGImagePropertyTIFFOrientation as String] as? NSNumber)?.uint32Value ?? CGImagePropertyOrientation.up.rawValue)
            
            if timestamp == nil, let dateTimeString = (TIFF[kCGImagePropertyTIFFDateTime as String] as? String) {
                timestamp = EXIFDateFormatter.date(from: dateTimeString)
            }
        }
        
        /*
         If image dimension didn't appear in metadata (can happen with some RAW files like Nikon NEFs), take one more step:
         open the actual image. This thankfully doesn't appear to immediately load image data.
         */
        if width == nil || height == nil
        {
            let options: CFDictionary = [String(kCGImageSourceShouldCache): false] as NSDictionary as CFDictionary
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options)
            width = CGFloat((image?.width)!)
            height = CGFloat((image?.height)!)
        }
        
        let metadata = ImageMetadata(nativeSize: CGSize(width: width!, height: height!), nativeOrientation: orientation ?? .up, colorSpace: colorSpace, fNumber: fNumber, focalLength: focalLength, focalLength35mmEquivalent: focalLength35mm, ISO: ISO, shutterSpeed: shutterSpeed, cameraMaker: cameraMaker, cameraModel: cameraModel, timestamp: timestamp)
        return metadata
    }()
    
    private func dumpAllImageMetadata(_ imageSource: CGImageSource)
    {
        let metadata = CGImageSourceCopyMetadataAtIndex(imageSource, 0, nil)
        let options: [String: AnyObject] = [String(kCGImageMetadataEnumerateRecursively): true as CFNumber]
        var results = [String: AnyObject]()

        CGImageMetadataEnumerateTagsUsingBlock(metadata!, nil, options as CFDictionary?) { path, tag in
            
            if let value = CGImageMetadataTagCopyValue(tag) {
                results[path as String] = value
            }
            else {
                results[path as String] = "??" as NSString
            }
            return true
        }
        
        print("---- All metadata for \(self.imageURL.path): ----")
        
        for key in results.keys.sorted()
        {
            print("    \(key) = \(results[key]!)")
        }
        
        print("----")
    }
    
    public func loadImageMetadata(_ handler: ImageMetadataHandler, errorHandler: ImageLoadingErrorHandler) {
        guard let _ = self.imageSource else {
            precondition(false)
            return
        }
        
        if let metadata = self.imageMetadata {
            handler(metadata)
        }
        else {
            errorHandler(RAWImageLoaderError.failedToExtractImageMetadata(message: "Failed to read image properties for \(self.imageURL.path)"))
        }
    }
    
    private func loadThumbnailImage(maximumPixelDimensions maximumSize: CGSize? = nil) -> CGImage?
    {
        guard let source = self.imageSource else {
            precondition(false)
            return nil
        }
        
        let maxPixelSize = maximumSize?.maximumPixelSize(forImageSize: self.imageMetadata!.size)
        var createFromFullImage = false
        
        if self.thumbnailScheme == .decodeFullImage {
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
        
        var options: [String: AnyObject] = [String(kCGImageSourceCreateThumbnailWithTransform): kCFBooleanTrue, String(createFromFullImage ? kCGImageSourceCreateThumbnailFromImageAlways : kCGImageSourceCreateThumbnailFromImageIfAbsent): kCFBooleanTrue]
        
        if let sz = maxPixelSize {
            options[String(kCGImageSourceThumbnailMaxPixelSize)] = NSNumber(value: Int(round(sz)))
        }
        
        let thumbnailImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary?)
        return thumbnailImage
    }
    
    public func loadThumbnailImage(maximumPixelDimensions maxPixelSize: CGSize? = nil, handler: PresentableImageHandler, errorHandler: ImageLoadingErrorHandler)
    {
        guard self.imageSource != nil else {
            precondition(false)
            return
        }
        
        if let thumbnailImage = loadThumbnailImage(maximumPixelDimensions: maxPixelSize) {
            handler(BitmapImageUtility.image(cgImage: thumbnailImage, size: CGSize.zero), self.imageMetadata!)
        }
        else {
            errorHandler(RAWImageLoaderError.failedToLoadThumbnailImage(message: "Failed to load thumbnail image from \(self.imageURL.path)"))
        }
    }
    
    static let genericLinearRGBColorSpace = CGColorSpace(name: CGColorSpace.genericRGBLinear)
    static let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB)
    
    @available(OSX 10.12, *)
    static let imageBakingColorSpace = genericLinearRGBColorSpace //NSScreen.deepest()?.colorSpace?.cgColorSpace ?? genericLinearRGBColorSpace
    
    //@available(OSX 10.12, *)
    //static let imageBakingContext = CIContext(options: [kCIContextCacheIntermediates: false, kCIContextUseSoftwareRenderer: false, kCIContextWorkingColorSpace: RAWImageLoader.imageBakingColorSpace, kCIContextOutputColorSpace: NSScreen.deepest()?.colorSpace?.cgColorSpace ?? RAWImageLoader.imageBakingColorSpace])
    //static let imageBakingContext = CIContext(options: [kCIContextCacheIntermediates: false, kCIContextUseSoftwareRenderer: false])
    
    @available(OSX 10.12, *)
    private static var _imageBakingContexts = [String: CIContext]()
    
    @available(OSX 10.12, *)
    private static func bakingContext(forImageURL URL: URL) -> CIContext
    {
        let ext = URL.pathExtension
        
        if let context = _imageBakingContexts[ext] {
            return context
        }
        
        let context = CIContext(options: [kCIContextCacheIntermediates: false, kCIContextUseSoftwareRenderer: false])
        _imageBakingContexts[ext] = context
        return context
    }
    
    public func loadFullSizeImage(handler: PresentableImageHandler, errorHandler: ImageLoadingErrorHandler) {
        self.loadFullSizeImage(options: FullSizedImageLoadingOptions(), handler: handler, errorHandler: errorHandler)
    }
    
    public func loadFullSizeImage(options: FullSizedImageLoadingOptions,
                                  handler: PresentableImageHandler,
                                  errorHandler: ImageLoadingErrorHandler)
    {
        guard let metadata = self.imageMetadata else {
            errorHandler(RAWImageLoaderError.failedToExtractImageMetadata(message: "Failed to read properties of \(self.imageURL.path) to load full-size image")); return
        }
        
        let scaleFactor: Double
        
        if let sz = options.maximumPixelDimensions
        {
            let imageSize = metadata.size
            let height = sz.scaledHeight(forImageSize: imageSize)
            scaleFactor = Double(height / imageSize.height)
        }
        else {
            scaleFactor = 1.0
        }
        
        let fail = {
            errorHandler(.failedToLoadFullSizeImage(message: "Failed to load full-size RAW image \(self.imageURL.path)"))
        }
        
        guard let RAWFilter = CIFilter(imageURL: self.imageURL, options: nil) else {
            fail()
            return
        }
        
        // NOTE: Having draft mode on appears to be crucial to performance, 
        // with a difference of 0.3s vs. 2.5s per image on this iMac 5K, for instance.
        // The quality is still quite excellent for displaying scaled-down presentations in a collection view, 
        // subjectively better than what you get from LibRAW with the half-size option.
        RAWFilter.setValue(true, forKey: kCIInputAllowDraftModeKey)
        RAWFilter.setValue(scaleFactor, forKey: kCIInputScaleFactorKey)
        
        RAWFilter.setValue(options.noiseReductionAmount, forKey: kCIInputNoiseReductionAmountKey)
        RAWFilter.setValue(options.colorNoiseReductionAmount, forKey: kCIInputColorNoiseReductionAmountKey)
        RAWFilter.setValue(options.noiseReductionSharpnessAmount, forKey: kCIInputNoiseReductionSharpnessAmountKey)
        RAWFilter.setValue(options.noiseReductionContrastAmount, forKey: kCIInputNoiseReductionContrastAmountKey)
        RAWFilter.setValue(options.boostShadowAmount, forKey: kCIInputBoostShadowAmountKey)
        RAWFilter.setValue(options.enableVendorLensCorrection, forKey: kCIInputEnableVendorLensCorrectionKey)
        
        /*var image = RAWFilter?.outputImage
        
        if let filters = image?.autoAdjustmentFilters(options: [kCIImageAutoAdjustEnhance: false]) //, kCIImageAutoAdjustFeatures: [CIFaceFeature()]])
        {
            for f in filters
            {
                f.setValue(image, forKey: kCIInputImageKey)
                image = f.outputImage
            }
            
            if let image = image*/
            if let image = RAWFilter.outputImage
            {
                var bakedImage: BitmapImage? = nil
                if #available(OSX 10.12, *)
                {
                    // Pixel format and color space set as discussed around 21:50 in https://developer.apple.com/videos/play/wwdc2016/505/
                    let context = RAWImageLoader.bakingContext(forImageURL: self.imageURL)
                    if let cgImage = context.createCGImage(image,
                        from: image.extent,
                        format: kCIFormatRGBA8,
                        colorSpace: RAWImageLoader.imageBakingColorSpace,
                        deferred: false) // The `deferred: false` argument is important, to ensure significant work will not be performed later on the main thread at drawing time
                    {
                        bakedImage = BitmapImageUtility.image(cgImage: cgImage, size: CGSize.zero)
                    }
                }
                
                if bakedImage == nil
                {
                    bakedImage = BitmapImageUtility.image(ciImage: image)
                }
                
                guard let nonNilNakedImage = bakedImage else {
                    fail()
                    return
                }

                handler(nonNilNakedImage, ImageMetadata(nativeSize: nonNilNakedImage.size))
            }
        //}
    }
}

public extension CGSize
{
    init(constrainWidth w: CGFloat)
    {
        self.width = w
        self.height = CGFloat.greatestFiniteMagnitude
    }
    
    init(constrainHeight h: CGFloat)
    {
        self.width = CGFloat.greatestFiniteMagnitude
        self.height = h
    }
    
    /** Assuming this NSSize value describes desired maximum width and/or height of a scaled output image, return appropriate value for the `kCGImageSourceThumbnailMaxPixelSize` option. */
    func maximumPixelSize(forImageSize imageSize: CGSize) -> CGFloat
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
    
    func scaledHeight(forImageSize imageSize: CGSize) -> CGFloat
    {
        return min(imageSize.height, self.height)
    }
}

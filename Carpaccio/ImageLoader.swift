//
//  ImageLoader.swift
//  Carpaccio
//
//  Created by Markus Piipari on 31/07/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation

import CoreGraphics
import CoreImage
import ImageIO

/** Implementation of ImageLoaderProtocol, capable of dealing with RAW file formats, 
  * as well common compressed image file formats. */
public class ImageLoader: ImageLoaderProtocol, URLBackedImageLoaderProtocol
{
   enum Error: Swift.Error {
        case filterInitializationFailed(URL: URL)
    }
    
    public enum ThumbnailScheme: Int {
        case never
        case decodeFullImage
        case fullImageWhenTooSmallThumbnail
        case fullImageWhenThumbnailMissing
    }
    
    public let imageURL: URL
    public let cachedImageURL: URL? = nil // For now, we don't implement a disk cache for images loaded by ImageLoader
    public let thumbnailScheme: ThumbnailScheme
    
    // See ImageMetadata.timestamp for known caveats about EXIF/TIFF
    // date metadata, as interpreted by this date formatter.
    private static let EXIFDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()
    
    public required init(imageURL: URL, thumbnailScheme: ThumbnailScheme) {
        self.imageURL = imageURL
        self.thumbnailScheme = thumbnailScheme
    }
    
    private func imageSource() -> CGImageSource? {
        // We intentionally don't store the image source, to not gob up resources, but rather open it anew each time
        let options = [String(kCGImageSourceShouldCache): false,
                       String(kCGImageSourceShouldAllowFloat): true] as NSDictionary as CFDictionary
        let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, options)
        return imageSource
    }
    
    public lazy var imageMetadata: ImageMetadata? = {

        guard let imageSource = self.imageSource() else {
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
        
        for key in results.keys.sorted() {
            print("    \(key) = \(results[key]!)")
        }
        
        print("----")
    }
    
    public func loadImageMetadata() throws -> ImageMetadata {
        guard let _ = self.imageSource() else {
            throw ImageLoadingError.noImageSource(URL: self.imageURL,
                                                  message: "Image source unexpectedly missing.")
        }
        
        guard let metadata = self.imageMetadata else {
            throw ImageLoadingError.failedToExtractImageMetadata(URL: self.imageURL,
                                                                 message: "Failed to read image properties for \(self.imageURL.path)")
        }
        
        return metadata
    }
    
    public func loadThumbnailCGImage(maximumPixelDimensions maximumSize: CGSize? = nil,
                                     allowCropping: Bool = true) throws -> (CGImage, ImageMetadata)
    {
        guard let source = self.imageSource() else {
            throw ImageLoadingError.noImageSource(URL: self.imageURL, message: "Image source is unexpectedly missing when loading thumbnail image.")
        }
        
        guard self.thumbnailScheme != .never else {
            throw ImageLoadingError.loadingSetToNever(URL: self.imageURL, message: "Image thumbnail failed to be loaded as the loader responsible for it is set to never load thumbnails.")
        }
        
        guard let metadata = self.imageMetadata else {
            throw ImageLoadingError.expectingMetadata(URL: self.imageURL, message: "Expecting image metadata to have been loaded before thumbnail is loaded.")
        }
        
        let maxPixelSize = maximumSize?.maximumPixelSize(forImageSize: metadata.size)
        let createFromFullImage = self.thumbnailScheme == .decodeFullImage
        
        var options: [String: AnyObject] = [String(kCGImageSourceCreateThumbnailWithTransform): kCFBooleanTrue,
                                            String(createFromFullImage ? kCGImageSourceCreateThumbnailFromImageAlways : kCGImageSourceCreateThumbnailFromImageIfAbsent): kCFBooleanTrue]
        
        if let sz = maxPixelSize {
            options[String(kCGImageSourceThumbnailMaxPixelSize)] = NSNumber(value: Int(round(sz)))
        }
        
        guard let thumbnailImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary?) else {
            throw ImageLoadingError.noImageSource(URL: self.imageURL,
                                                  message: "Failed to load thumbnail image as creating an image source for it failed.")
        }
        
        if !allowCropping {
            return (thumbnailImage, metadata)
        }
        
        return (cropToNativeProportionsIfNeeded(thumbnailImage: thumbnailImage), metadata)
    }
    
    /**
     
     If the proportions of thumbnail image don't match those of the native full size, crop to the same proportions.
     
     This, for example, can happen with Nikon RAW files, where the smallest thumbnail included in a NEF file can be 4:3,
     while the actual full-size image is 3:2. In that case, the thumbnail will contain black bars around the actual image,
     to extend 3:2 to 4:3 proportions. The solution: crop.
     
     */
    private func cropToNativeProportionsIfNeeded(thumbnailImage thumbnail: CGImage) -> CGImage
    {
        guard let metadata = imageMetadata else {
            return thumbnail;
        }
        
        let thumbnailSize = CGSize(width: CGFloat(thumbnail.width), height:CGFloat(thumbnail.height))
        let absThumbAspectDiff = fabs(metadata.size.aspectRatio - thumbnailSize.aspectRatio)
        
        // small differences can happen and in those cases we should not crop but simply rescale the thumbnail
        // (to avoid decreasing image quality).
        let metadataAndThumbAgreeOnAspectRatio = absThumbAspectDiff < 0.01
        
        if metadataAndThumbAgreeOnAspectRatio {
            return thumbnail
        }
        
        let cropRect: CGRect?
        
        switch metadata.shape
        {
        case .landscape:
            let expectedHeight = metadata.size.proportionalHeight(forWidth: CGFloat(thumbnail.width))
            let d = Int(round(abs(expectedHeight - CGFloat(thumbnail.height))))
            if (d >= 1)
            {
                let cropAmount: CGFloat = 0.5 * (d % 2 == 0 ? CGFloat(d) : CGFloat(d + 1))
                cropRect = CGRect(x: 0.0, y: cropAmount, width: CGFloat(thumbnail.width), height: CGFloat(thumbnail.height) - 2.0 * cropAmount)
            }
            else
            {
                cropRect = nil
            }
        case .portrait:
            let expectedWidth = metadata.size.proportionalWidth(forHeight: CGFloat(thumbnail.height))
            let d = Int(round(abs(expectedWidth - CGFloat(thumbnail.width))))
            if (d >= 1)
            {
                let cropAmount: CGFloat = 0.5 * (d % 2 == 0 ? CGFloat(d) : CGFloat(d + 1))
                cropRect = CGRect(x: cropAmount, y: 0.0, width: CGFloat(thumbnail.width) - 2.0 * cropAmount, height: CGFloat(thumbnail.height))
            }
            else
            {
                cropRect = nil
            }
        case .square:
            // highly unlikely to actually occur – 
            // as I'm not sure what the correct procedure here would be,
            // I will do nothing.
            cropRect = nil
        }
        
        if let r = cropRect, let croppedThumbnail = thumbnail.cropping(to: r) {
            return croppedThumbnail
        }
        
        return thumbnail
    }
    
    /** Retrieve metadata about this loader's image, to be called before loading actual image data. */
    public func loadThumbnailImage(maximumPixelDimensions maxPixelSize: CGSize?, allowCropping: Bool) throws -> (BitmapImage, ImageMetadata) {
        let (thumbnailImage, metadata) = try loadThumbnailCGImage(maximumPixelDimensions: maxPixelSize, allowCropping: allowCropping)
        return (BitmapImageUtility.image(cgImage: thumbnailImage, size: CGSize.zero), metadata)
    }
    
    static let genericLinearRGBColorSpace = CGColorSpace(name: CGColorSpace.genericRGBLinear)
    static let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB)
    
    @available(OSX 10.12, *)
    static let imageBakingColorSpace = genericLinearRGBColorSpace //NSScreen.deepest()?.colorSpace?.cgColorSpace ?? genericLinearRGBColorSpace
    
    //@available(OSX 10.12, *)
    //static let imageBakingContext = CIContext(options: [kCIContextCacheIntermediates: false, kCIContextUseSoftwareRenderer: false, kCIContextWorkingColorSpace: ImageLoader.imageBakingColorSpace, kCIContextOutputColorSpace: NSScreen.deepest()?.colorSpace?.cgColorSpace ?? ImageLoader.imageBakingColorSpace])
    //static let imageBakingContext = CIContext(options: [kCIContextCacheIntermediates: false, kCIContextUseSoftwareRenderer: false])
    
    @available(OSX 10.12, *)
    private static var _imageBakingContexts = [String: CIContext]()
    
    @available(OSX 10.12, *)
    private static func bakingContext(for imageURL: URL) -> CIContext
    {
        let ext = imageURL.pathExtension
        
        if let context = _imageBakingContexts[ext] {
            return context
        }
        
        let context = CIContext(options: [kCIContextCacheIntermediates: false, kCIContextUseSoftwareRenderer: false])
        _imageBakingContexts[ext] = context
        return context
    }
    
    public func loadFullSizeImage(options: FullSizedImageLoadingOptions) throws -> (BitmapImage, ImageMetadata)
    {
        guard let metadata = self.imageMetadata else {
            throw ImageLoadingError.failedToExtractImageMetadata(
                URL: self.imageURL,
                message: "Failed to read properties of \(self.imageURL.path) to load full-size image")
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
        
        guard let RAWFilter = CIFilter(imageURL: self.imageURL, options: nil) else {
            throw ImageLoadingError.failedToInitializeDecoder(URL: self.imageURL,
                                                              message: "Failed to load full-size RAW image \(self.imageURL.path)")
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
        
        guard let image = RAWFilter.outputImage else {
            throw ImageLoadingError.failedToDecode(URL: self.imageURL,
                                                   message: "Failed to decode full-size RAW image \(self.imageURL.path)")
        }
        var bakedImage: BitmapImage? = nil
        if #available(OSX 10.12, *)
        {
            // Pixel format and color space set as discussed around 21:50 in https://developer.apple.com/videos/play/wwdc2016/505/
            let context = ImageLoader.bakingContext(for: self.imageURL)
            if let cgImage = context.createCGImage(image,
                from: image.extent,
                format: kCIFormatRGBA8,
                colorSpace: ImageLoader.imageBakingColorSpace,
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
            throw ImageLoadingError.failedToLoadDecodedImage(URL: self.imageURL,
                                                             message: "Failed to load decoded image \(self.imageURL.path)")
        }

        return (nonNilNakedImage, metadata)
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
        let ratio = imageSize.aspectRatio
        
        if widthIsUnconstrained && heightIsUnconstrained
        {
            if ratio > 1.0 {
                return imageSize.width
            }
            return imageSize.height
        }
        else if widthIsUnconstrained {
            if ratio > 1.0 {
                return imageSize.proportionalWidth(forHeight: self.height)
            }
            return self.height
        }
        else if heightIsUnconstrained {
            if ratio > 1.0 {
                return self.width
            }
            return imageSize.proportionalHeight(forWidth: self.width)
        }
        
        return min(self.width, self.height)
    }
    
    func scaledHeight(forImageSize imageSize: CGSize) -> CGFloat
    {
        return min(imageSize.height, self.height)
    }
}

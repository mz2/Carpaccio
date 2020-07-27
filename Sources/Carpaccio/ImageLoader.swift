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

/**
 Implementation of ImageLoaderProtocol, capable of dealing with RAW file formats,
 as well common compressed image file formats.
 */
public class ImageLoader: ImageLoaderProtocol, URLBackedImageLoaderProtocol {
    enum Error: Swift.Error, LocalizedError {
        case filterInitializationFailed(URL: URL)

        var errorDescription: String? {
            switch self {
            case .filterInitializationFailed(let URL):
                return "Failed to initialize image loader filter for image at URL \(URL)"
            }
        }

        var failureReason: String? {
            switch self {
            case .filterInitializationFailed(let URL):
                return "Failed to initialize image loader filter for file at \"\(URL)\""
            }
        }

        var helpAnchor: String? {
            return "Ensure that images of the kind you are trying to load are supported by your system."
        }

        var recoverySuggestion: String? {
            return self.helpAnchor
        }
    }

    public enum ThumbnailScheme: Int {
        case decodeFullImage
        case decodeFullImageIfEmbeddedThumbnailTooSmall
        case decodeFullImageIfEmbeddedThumbnailMissing
        case decodeEmbeddedThumbnail

        /**

         With this thumbnail scheme in effect, determine if the full size image should be loaded, given:

         - An already loaded thumbnail image candidate (if any)

         - A target maximum size (if any)

         - A threshold for how much smaller the thumbnail image can be in each dimension, and still qualify.

           Default ratio is 1.0, meaning either the thumbnail image candidate's width or height must be equal
           to, or greater than, the width or height of the given target maximum size. If, say, a 20% smaller
           thumbnail image (in either width or height) is fine to scale up for display, you would provide a
           `ratio` value of `0.80`.

         */
        public func shouldDecodeFullImage(having thumbnailCGImage: CGImage?, desiredMaximumPixelDimensions targetMaxSize: CGSize?, ratio: CGFloat = 1.0) -> Bool {
            switch self {
            case .decodeFullImage:
                return true
            case .decodeFullImageIfEmbeddedThumbnailMissing:
                return thumbnailCGImage == nil
            case .decodeFullImageIfEmbeddedThumbnailTooSmall:
                guard let cgImage = thumbnailCGImage else {
                    // No candidate thumbnail has been loaded yet, so must load full image
                    return true
                }
                guard let targetMaxSize = targetMaxSize else {
                    // There is no size requirement, so no point in loading full image
                    return false
                }
                return !cgImage.size.isSufficientToFulfill(targetSize: targetMaxSize, atMinimumRatio: ratio)
            case .decodeEmbeddedThumbnail:
                return false
            }
        }
    }
    
    public let imageURL: URL
    public let cachedImageURL: URL? = nil // For now, we don't implement a disk cache for images loaded by ImageLoader
    public let thumbnailScheme: ThumbnailScheme
    
    public required init(imageURL: URL, thumbnailScheme: ThumbnailScheme) {
        self.imageURL = imageURL
        self.thumbnailScheme = thumbnailScheme
    }
    
    public required init(imageLoader otherLoader: ImageLoaderProtocol, thumbnailScheme: ThumbnailScheme) {
        self.imageURL = otherLoader.imageURL
        self.thumbnailScheme = thumbnailScheme
        if otherLoader.imageMetadataState == .completed, let metadata = try? otherLoader.loadImageMetadata() {
            self.cachedImageMetadata = metadata
            self.imageMetadataState = .completed
        }
    }
    
    private func imageSource() throws -> CGImageSource {
        // We intentionally don't store the image source, to not gob up resources, but rather open it anew each time
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, options) else{
            throw CGImageExtensionError.failedToOpenCGImage(url: imageURL)
        }
        
        return imageSource
    }
    
    public private(set) var imageMetadataState: ImageMetadataState = .initialized
    internal fileprivate(set) var cachedImageMetadata: ImageMetadata?

    public func updateCachedMetadata(_ metadata: ImageMetadata) {
        self.cachedImageMetadata = metadata
        self.imageMetadataState = .completed
    }

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
        let metadata = try loadImageMetadataIfNeeded()
        return metadata
    }
    
    var count = 0
    
    internal func loadImageMetadataIfNeeded(forceReload: Bool = false) throws -> ImageMetadata {
        count += 1
        
        if forceReload {
            imageMetadataState = .initialized
            cachedImageMetadata = nil
        }
        
        if imageMetadataState == .initialized {
            do {
                imageMetadataState = .loading
                let imageSource = try self.imageSource()
                let metadata = try ImageMetadata(imageSource: imageSource)
                cachedImageMetadata = metadata
                imageMetadataState = .completed
            } catch {
                imageMetadataState = .failed
                throw error
            }
        }
        
        guard let metadata = cachedImageMetadata, imageMetadataState == .completed else {
            throw Image.Error.noMetadata
        }
        
        return metadata
    }

    public func loadCGImage(
        maximumPixelDimensions maximumSize: CGSize? = nil,
        colorSpace: CGColorSpace?,
        allowCropping: Bool = true,
        cancelled cancelChecker: CancellationChecker?
    ) throws -> (CGImage, ImageMetadata) {

        let metadata = try loadImageMetadataIfNeeded()
        let source = try imageSource()
        
        // Load thumbnail
        try stopIfCancelled(cancelChecker, "Before loading thumbnail image")

        let createFromFullImage = thumbnailScheme == .decodeFullImage

        var options: [String: AnyObject] = {
            var options: [String: AnyObject] = [
                String(kCGImageSourceCreateThumbnailWithTransform): kCFBooleanTrue,
                String(kCGImageSourceShouldCacheImmediately): kCFBooleanTrue,
                String(kCGImageSourceShouldAllowFloat): kCFBooleanTrue
            ]

            if createFromFullImage {
                options[String(kCGImageSourceCreateThumbnailFromImageAlways)] = kCFBooleanTrue
            } else {
                options[String(kCGImageSourceCreateThumbnailFromImageIfAbsent)] = kCFBooleanTrue
            }

            if let maximumPixelDimension = maximumSize?.maximumPixelSize(forImageSize: metadata.size) {
                options[String(kCGImageSourceThumbnailMaxPixelSize)] = NSNumber(value: maximumPixelDimension)
            }

            return options
        }()
        
        let thumbnailImage: CGImage = try {
            let thumbnailCandidate = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary?)

            // Retry from full image, if needed, and wasn't already
            guard let thumbnail: CGImage = {
                if !createFromFullImage && thumbnailScheme.shouldDecodeFullImage(having: thumbnailCandidate, desiredMaximumPixelDimensions: maximumSize, ratio: 1.0) {
                    options[kCGImageSourceCreateThumbnailFromImageAlways as String] = kCFBooleanTrue
                    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary?)
                }
                return thumbnailCandidate
            }() else {
                throw ImageLoadingError.noImageSource(URL: self.imageURL, message: "Failed to load thumbnail")
            }

            // Convert color space, if needed
            guard let colorSpace = colorSpace else {
                return thumbnail
            }

            try stopIfCancelled(cancelChecker, "Before converting color space of thumbnail image")

            let image = try thumbnail.convertedToColorSpace(colorSpace)
            return image
        }()

        // Crop letterboxing out, if needed
        guard allowCropping else {
            return (thumbnailImage, metadata)
        }

        try stopIfCancelled(cancelChecker, "Before cropping to native proportions")

        return (ImageLoader.cropToNativeProportionsIfNeeded(thumbnailImage: thumbnailImage, metadata: metadata), metadata)
    }
    
    /**
     
     If the proportions of thumbnail image don't match those of the native full size, crop to the same proportions.
     
     This, for example, can happen with Nikon RAW files, where the smallest thumbnail included in a NEF file can be 4:3,
     while the actual full-size image is 3:2. In that case, the thumbnail will contain black bars around the actual image,
     to extend 3:2 to 4:3 proportions. The solution: crop.
     
     */
    public class func cropToNativeProportionsIfNeeded(thumbnailImage thumbnail: CGImage, metadata: ImageMetadata) -> CGImage
    {
        let thumbnailSize = CGSize(width: CGFloat(thumbnail.width), height:CGFloat(thumbnail.height))
        let absThumbAspectDiff = abs(metadata.size.aspectRatio - thumbnailSize.aspectRatio)
        
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
            let expectedHeight = metadata.size.proportionalHeight(forWidth: CGFloat(thumbnail.width), precision: .defaultPrecisionScheme)
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
            let expectedWidth = metadata.size.proportionalWidth(forHeight: CGFloat(thumbnail.height), precision: .defaultPrecisionScheme)
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
    
    /** Retrieve a thumbnail image for this loader's image. */
    public func loadBitmapImage(maximumPixelDimensions maxPixelSize: CGSize?, colorSpace: CGColorSpace?, allowCropping: Bool, cancelled: CancellationChecker?) throws -> (BitmapImage, ImageMetadata) {
        let (thumbnailImage, metadata) = try loadCGImage(maximumPixelDimensions: maxPixelSize, colorSpace: colorSpace, allowCropping: allowCropping, cancelled: cancelled)
        return (BitmapImageUtility.image(cgImage: thumbnailImage, size: CGSize.zero), metadata)
    }

    public func loadCIImage(options: ImageLoadingOptions, cancelled: CancellationChecker?) throws -> (CIImage, ImageMetadata) {
        let metadata = try loadImageMetadataIfNeeded()
        try stopIfCancelled(cancelled, "Before loading editable image")
        let ciImage = try CIImage.loadCIImage(from: imageURL, imageMetadata: metadata, options: options)
        return (ciImage, metadata)
    }
}

//
//  ImageLoading.swift
//  Carpaccio
//
//  Created by Markus Piipari on 27/07/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation
import QuartzCore

public typealias ImageMetadataHandler = (_ metadata: ImageMetadata) -> Void

public typealias PresentableImageHandler = (_ image: BitmapImage, _ metadata: ImageMetadata) -> Void

public enum ImageLoadingError: Swift.Error
{
    case failedToExtractImageMetadata(URL: URL, message: String)
    case failedToLoadThumbnailImage(URL: URL, message: String)
    case failedToLoadFullSizeImage(URL: URL, message: String)
    case noImageSource(URL: URL, message: String)
    case failedToInitializeDecoder(URL: URL, message: String)
    case failedToDecode(URL: URL, message: String)
    case failedToLoadDecodedImage(URL: URL, message: String)
    case loadingSetToNever(URL: URL, message: String)
    case expectingMetadata(URL: URL, message: String)
    case failedToConvertColorSpace(url: URL, message: String)
    case cancelled(url: URL, message: String)
}

public typealias ImageLoadingErrorHandler = (_ error: ImageLoadingError) -> Void

public struct FullSizedImageLoadingOptions {
    public var maximumPixelDimensions:CGSize?
    public var allowDraftMode = true
    public var noiseReductionAmount = 0.5
    public var colorNoiseReductionAmount = 1.0
    public var noiseReductionSharpnessAmount = 0.5
    public var noiseReductionContrastAmount = 0.5
    public var boostShadowAmount = 1.0
    public var enableVendorLensCorrection = true
    
    // for some reason compiler is not happy otherwise when this is used from outside.
    public init() { }
}

/**
 
 This enumeration indicates the current stage of loading an image's metadata. The values
 can be used by a client to determine whether a particular image should be completely
 omitted, or if an error indication should be communicated to the user.
 
 */
public enum ImageLoaderMetadataState {
    /** Metadata has not yet been loaded. */
    case initialized
    
    /** Metadata is currently being loaded. */
    case loadingMetadata
    
    /** Loading image metadata has succesfully completed. */
    case completed
    
    /** Loading image metadata failed with an error. */
    case failed
}

/**
 Closure type for determining if a potentially lengthy thumbnail image loading step should
 not be performed after all, due to the image not being needed anymore.
 */
public typealias CancellationChecker = () -> Bool

public protocol ImageLoaderProtocol
{
    var imageURL: URL { get }
    var imageMetadataState: ImageLoaderMetadataState { get }
    var colorSpace: CGColorSpace? { get }
    
    /** _If_, in addition to `imageURL`, full image image data happens to have been copied into a disk cache location,
      * a direct URL pointing to that location. */
    var cachedImageURL: URL? { get }
    
    /**
     Load image metadata synchronously. After a first succesful load, an implementation may choose to return a cached
     copy on later calls.
     */
    func loadImageMetadata() throws -> ImageMetadata
    
    /**
     Load a thumbnail representation of this loader's associated image, optionally:
     - Scaled down to a maximum pixel size
     - Cropped to the proportions of the image's metadata (to remove letterboxing by some cameras' thumbnails)
     */
    func loadThumbnailImage(maximumPixelDimensions maxPixelSize: CGSize?, allowCropping: Bool, cancelled: CancellationChecker?) throws -> (BitmapImage, ImageMetadata)
    
    func loadThumbnailCGImage(maximumPixelDimensions maximumSize: CGSize?, allowCropping: Bool, cancelled: CancellationChecker?) throws -> (CGImage, ImageMetadata)
    
    func loadThumbnailImage(cancelled: CancellationChecker?) throws -> (BitmapImage, ImageMetadata)
    
    /** Load full-size image. */
    func loadFullSizeImage(options: FullSizedImageLoadingOptions) throws -> (BitmapImage, ImageMetadata)
    
    /** Load full-size image with default options. */
    func loadFullSizeImage() throws -> (BitmapImage, ImageMetadata)
}

public protocol URLBackedImageLoaderProtocol: ImageLoaderProtocol {
    init(imageURL: URL, thumbnailScheme: ImageLoader.ThumbnailScheme, colorSpace: CGColorSpace?)
    init(imageLoader: ImageLoaderProtocol, thumbnailScheme: ImageLoader.ThumbnailScheme, colorSpace: CGColorSpace?)
}

public extension ImageLoaderProtocol {
    func loadThumbnailImage(cancelled: CancellationChecker?) throws -> (BitmapImage, ImageMetadata) {
        return try self.loadThumbnailImage(maximumPixelDimensions: nil, allowCropping: true, cancelled: cancelled)
    }
    
    func loadThumbnailImage(maximumPixelDimensions: CGSize?, cancelled: CancellationChecker?) throws -> (BitmapImage, ImageMetadata) {
        return try self.loadThumbnailImage(maximumPixelDimensions: maximumPixelDimensions, allowCropping: true, cancelled: cancelled)
    }
    
    func loadThumbnailImage(allowCropping: Bool, cancelled: CancellationChecker?) throws -> (BitmapImage, ImageMetadata) {
        return try self.loadThumbnailImage(maximumPixelDimensions: nil, allowCropping: allowCropping, cancelled: cancelled)
    }
    
    func loadFullSizeImage() throws -> (BitmapImage, ImageMetadata) {
        return try self.loadFullSizeImage(options: FullSizedImageLoadingOptions())
    }
}

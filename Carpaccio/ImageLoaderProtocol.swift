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

public protocol ImageLoaderProtocol
{
    var imageURL: URL { get }
    var imageMetadata: ImageMetadata { get }
    
    /** *If*, in addition to `imageURL`, full image image data happens to have been copied into a disk cache location,
      * a direct URL pointing to that location. */
    var cachedImageURL: URL? { get }
    
    func loadThumbnailCGImage(maximumPixelDimensions maximumSize: CGSize?, allowCropping: Bool) throws -> (CGImage, ImageMetadata)
    
    /** Retrieve metadata about this loader's image, potentially called before loading actual image data. */
    func loadThumbnailImage(maximumPixelDimensions maxPixelSize: CGSize?, allowCropping: Bool) throws -> (BitmapImage, ImageMetadata)
    
    func loadThumbnailImage() throws -> (BitmapImage, ImageMetadata)
    
    /** Load image metadata synchronously. */
    func loadImageMetadata() throws -> ImageMetadata
    
    /** Load full-size image. */
    func loadFullSizeImage(options: FullSizedImageLoadingOptions) throws -> (BitmapImage, ImageMetadata)
    
    /** Load full-size image with default options. */
    func loadFullSizeImage() throws -> (BitmapImage, ImageMetadata)
}

public extension ImageLoaderProtocol {
    func loadThumbnailImage() throws -> (BitmapImage, ImageMetadata) {
        return try self.loadThumbnailImage(maximumPixelDimensions: nil, allowCropping: true)
    }
    
    func loadThumbnailImage(maximumPixelDimensions: CGSize?) throws -> (BitmapImage, ImageMetadata) {
        return try self.loadThumbnailImage(maximumPixelDimensions: maximumPixelDimensions, allowCropping: true)
    }
    
    func loadThumbnailImage(allowCropping: Bool) throws -> (BitmapImage, ImageMetadata) {
        return try self.loadThumbnailImage(maximumPixelDimensions: nil, allowCropping: allowCropping)
    }
    
    func loadFullSizeImage() throws -> (BitmapImage, ImageMetadata) {
        return try self.loadFullSizeImage(options: FullSizedImageLoadingOptions())
    }
}

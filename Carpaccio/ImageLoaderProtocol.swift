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

public typealias ImageLoadingErrorHandler = (_ error: RAWImageLoaderError) -> Void

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
    var imageMetadata: ImageMetadata? { get }
    
    /** *If*, in addition to `imageURL`, full image image data happens to have been copied into a disk cache location, a direct URL pointing to that location. */
    var cachedImageURL: URL? { get }
    
    /** Retrieve metadata about this loader's image, to be called before loading actual image data. */
    func loadThumbnailImage(maximumPixelDimensions maxPixelSize: CGSize?,
                            handler: @escaping PresentableImageHandler,
                            errorHandler: @escaping ImageLoadingErrorHandler)
    
    func loadThumbnailImage(handler: @escaping PresentableImageHandler,
                            errorHandler: @escaping ImageLoadingErrorHandler)
    
    /** Load image metadata. */
    func loadImageMetadata(_ handler: @escaping ImageMetadataHandler,
                           errorHandler: @escaping ImageLoadingErrorHandler)
    
    /** Load full-size image. */
    func loadFullSizeImage(options: FullSizedImageLoadingOptions,
                           handler: @escaping PresentableImageHandler,
                           errorHandler: @escaping ImageLoadingErrorHandler)
    
    func loadFullSizeImage(handler: @escaping PresentableImageHandler,
                           errorHandler: @escaping ImageLoadingErrorHandler)
}

public extension ImageLoaderProtocol {
    func loadThumbnailImage(handler: @escaping PresentableImageHandler,
                            errorHandler: @escaping ImageLoadingErrorHandler) {
        self.loadThumbnailImage(maximumPixelDimensions: nil,
                                handler: handler, errorHandler: errorHandler)
    }
    
    func loadFullSizeImage(handler: @escaping PresentableImageHandler,
                           errorHandler: @escaping ImageLoadingErrorHandler) {
        self.loadFullSizeImage(options:FullSizedImageLoadingOptions(),
                               handler: handler, errorHandler: errorHandler)
    }
}

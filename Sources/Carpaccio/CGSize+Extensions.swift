//
//  Utility.swift
//  Carpaccio
//
//  Created by Markus Piipari on 30/07/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation
import QuartzCore

public enum PrecisionScheme {
    /// Return precise value as-is.
    case precise

    /// Return precise value rounded down, using `FloatingPointRoundingRule.down`. Equivalent to `floor(preciseValue)`.
    case roundedDown

    /// Return precise value rounded, as per "schoolbook rounding" rule of `FloatingPointRoundingRule.toNearestOrAwayFromZero`.
    case rounded

    /// Return precise value rounded up, using `FloatingPointRoundingRule.up`. Equivalent to `ceil(preciseValue)`.
    case roundedUp

    /// Default precision scheme to use when not explicitly provided; returns `.rounded`.
    public static var defaultPrecisionScheme: PrecisionScheme {
        return .rounded
    }

    func applied<T: FloatingPoint>(to preciseValue: T) -> T {
        switch self {
        case .precise:
            return preciseValue
        case .roundedDown:
            return preciseValue.rounded(.down)
        case .rounded:
            return preciseValue.rounded(.toNearestOrAwayFromZero)
        case .roundedUp:
            return preciseValue.rounded(.up)
        }
    }
}

public extension CGFloat {
    static var unconstrained: CGFloat {
        infinity
    }

    var isLandscape: Bool {
        self > 1.0 && self < .infinity
    }

    var isPortrait: Bool {
        self > 0.0 && self < 1.0
    }

    var isSquare: Bool {
        self == 1.0
    }
}

public extension CGSize {
    init(constrainWidth width: CGFloat) {
        self.init(width: width, height: CGFloat.unconstrained)
    }

    init(constrainHeight height: CGFloat) {
        self.init(width: CGFloat.unconstrained, height: height)
    }

    static var unconstrained: CGSize {
        return CGSize(width: CGFloat.unconstrained, height: CGFloat.unconstrained)
    }

    var isConstrained: Bool {
        return width.isFinite || height.isFinite
    }

    var hasConstrainedHeight: Bool {
        return height.isFinite
    }

    var hasConstrainedWidth: Bool {
        return width.isFinite
    }

    var isUnconstrained: Bool {
        return !width.isFinite && !height.isFinite
    }

    var hasUnconstrainedHeight: Bool {
        return !height.isFinite
    }

    var hasUnconstrainedWidth: Bool {
        return !width.isFinite
    }

    static func * (size: CGSize, scale: CGFloat) -> CGSize {
        CGSize(width: size.width * scale, height: size.height * scale)
    }

    static func * (scale: CGFloat, size: CGSize) -> CGSize {
        size * scale
    }

    var aspectRatio: CGFloat {
        if self.width == 0.0 {
            return 0.0
        }
        if self.height == 0.0 {
            return CGFloat.infinity
        }
        return self.width / self.height
    }

    func proportionalSize(for imageSize: CGSize, precision: PrecisionScheme = .defaultPrecisionScheme) -> CGSize {
        let maximumDimension = CGFloat(maximumPixelSize(forImageSize: imageSize))
        let ratio = imageSize.aspectRatio
        if ratio.isLandscape {
            return CGSize(width: maximumDimension, height: precision.applied(to: maximumDimension / ratio))
        } else {
            return CGSize(width: precision.applied(to: ratio * maximumDimension), height: maximumDimension)
        }
    }

    ///
    /// Assuming this `CGSize` describes desired maximum width and/or height of a scaled output image, return the value for the
    /// `kCGImageSourceThumbnailMaxPixelSize` option, so that an image gets scaled down proportionally when loaded by Image I/O.
    ///
    func maximumPixelSize(forImageSize imageSize: CGSize) -> Int {
        let widthIsUnconstrained = self.width >= imageSize.width
        let heightIsUnconstrained = self.height >= imageSize.height
        let imageRatio = imageSize.aspectRatio
        let precision = PrecisionScheme.defaultPrecisionScheme

        if widthIsUnconstrained && heightIsUnconstrained {
            // Neither width not height is requested to be constrained to a specific number of pixels. This means that this CGSize
            // does not affect the calculation at all, so we return the appropriate (larger) image dimension.
            if imageRatio.isLandscape {
                return Int(precision.applied(to: imageSize.width))
            }
            return Int(precision.applied(to: imageSize.height))

        } else if widthIsUnconstrained {
            // A specific height is requested:
            if imageRatio.isLandscape {
                // The image is larger (or equal) in width than height. Proportional width will be the maximum pixel size.
                return Int(imageSize.proportionalWidth(forHeight: self.height, precision: precision))
            }
            // The image is larger in height than width. This CGSize's height will be the maximum pixel size.
            return Int(precision.applied(to: self.height))

        } else if heightIsUnconstrained {
            // A specific width is requested:
            if imageRatio.isLandscape {
                // The image is larger (or equal) in width than height. This CGSize's width will be the maximum pixel size.
                return Int(precision.applied(to: self.width))
            }
            // The image is larger in height than width. Proportional height will be the maximum pixel size.
            return Int(imageSize.proportionalHeight(forWidth: self.width, precision: precision))
        }

        // This CGSize constrains both width and height, effectively making it a bounding box. We need to:
        // - Calculate one dimension proportionally from the other
        // - Pick which one based on whether the image aspect ratio or this bounding aspect ratio is the wider one
        // - Return the larger result as the maximum pixel size
        let calculateHeightFromWidth = imageRatio >= self.aspectRatio
        let value: CGFloat

        if calculateHeightFromWidth {
            let width = min(self.width, imageSize.width)
            let height = imageSize.proportionalHeight(forWidth: width)
            value = max(width, height)
        } else {
            let height = min(self.height, imageSize.height)
            let width = imageSize.proportionalWidth(forHeight: height)
            value = max(width, height)
        }

        return Int(precision.applied(to: value))
    }

    // Calculate a target width based on a desired target height, such that the target width and height will have the same aspect
    // ratio as this `CGSize`.
    func proportionalWidth(forHeight height: CGFloat, precision: PrecisionScheme = .defaultPrecisionScheme) -> CGFloat {
        precision.applied(to: height * aspectRatio)
    }

    // Calculate a target height based on a desired target width, such that the target width and height will have the same aspect
    // ratio as this `CGSize`.
    func proportionalHeight(forWidth width: CGFloat, precision: PrecisionScheme = .defaultPrecisionScheme) -> CGFloat {
        precision.applied(to: width / aspectRatio)
    }
    
    func distance(to: CGSize) -> CGFloat {
        let xDist = to.width - self.width
        let yDist = to.width - self.width
        return sqrt((xDist * xDist) + (yDist * yDist))
    }

    /**

     Determine if either the width, or height, of this size is equal to, or larger than, a given maximum target
     size's width or height.

     The math performed can be scaled by a minimum ratio. For example, if a 50% smaller width or height is enough,
     you should use a `ratio` value of `0.50`. The default is a minimum ratio of `1.0`, meaning at least one of
     this size's dimensions must be greater than or equal to the same dimension of `targetMaxSize`.

     Note that if a dimension of `targetMaxSize` is set to `CGFloat.unconstrained`, that particular axis will not be
     considered. In such a case, _any_ value of this size, on that axis, is considered insufficient. In other words,
     a `targetMaxSize` of `CGSize(width: CGFloat.unconstrained, height: CGFloat.unconstrained)` will always return `false`.

     */
    func isSufficientToFulfill(targetSize: CGSize, atMinimumRatio ratio: CGFloat = 1.0) -> Bool {
        let widthIsSufficient: Bool = {
            let considerWidth = targetSize.width >= 1.0 && targetSize.hasConstrainedWidth
            if considerWidth {
                return ((1.0 / ratio) * width) >= targetSize.width
            }
            return true
        }()

        let heightIsSufficient: Bool = {
            let considerHeight = targetSize.height >= 1.0 && targetSize.hasConstrainedHeight
            if considerHeight {
                return ((1.0 / ratio) * height) >= targetSize.height
            }
            return true
        }()

        return widthIsSufficient && heightIsSufficient
    }
}

// MARK: - Comparable

/// Implement `Comparable` based on the logic that the pixel area (so, `width * height`) determines the inherent order of two
/// `CGSize` values.
extension CGSize: Comparable {
  public static func > (lhs: CGSize, rhs: CGSize) -> Bool {
    lhs.width * lhs.height > rhs.width * rhs.height
  }

  public static func >= (lhs: CGSize, rhs: CGSize) -> Bool {
    lhs.width * lhs.height >= rhs.width * rhs.height
  }

  public static func < (lhs: CGSize, rhs: CGSize) -> Bool {
    lhs.width * lhs.height < rhs.width * rhs.height
  }

  public static func <= (lhs: CGSize, rhs: CGSize) -> Bool {
    lhs.width * lhs.height <= rhs.width * rhs.height
  }
}

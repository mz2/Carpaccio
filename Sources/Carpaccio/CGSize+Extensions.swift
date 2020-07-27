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
    /** Return precise value as-is. */
    case precise

    /** Return precise value floored. */
    case floored

    /** Return precise value rounded. */
    case rounded

    func applied<T: FloatingPoint>(to preciseValue: T) -> T {
        switch self {
        case .precise:
            return preciseValue
        case .floored:
            return floor(preciseValue)
        case .rounded:
            return round(preciseValue)
        }
    }

    public static var defaultPrecisionScheme: PrecisionScheme {
        return .rounded
    }
}

public extension CGFloat {
    static var unconstrained: CGFloat {
        infinity
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

    static func > (lhs: CGSize, rhs: CGSize) -> Bool {
        lhs.width * lhs.height > rhs.width * rhs.height
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

    func proportionalSize(for imageSize: CGSize, precision: PrecisionScheme) -> CGSize {
        let maximumDimension = CGFloat(maximumPixelSize(forImageSize: imageSize))
        let ratio = imageSize.aspectRatio
        if ratio > 1.0 {
            return CGSize(width: precision.applied(to: maximumDimension), height: precision.applied(to: maximumDimension / ratio))
        } else {
            return CGSize(width: precision.applied(to: ratio * maximumDimension), height: precision.applied(to: maximumDimension))
        }
    }

    /**
     Assuming this CGSize value describes desired maximum width and/or height of a scaled output image,
     return an the value for the `kCGImageSourceThumbnailMaxPixelSize` option so that an image gets scaled
     down proportionally, if appropriate.
     */
    func maximumPixelSize(forImageSize imageSize: CGSize) -> Int {
        let widthIsUnconstrained = self.width >= imageSize.width
        let heightIsUnconstrained = self.height >= imageSize.height
        let ratio = imageSize.aspectRatio

        if widthIsUnconstrained && heightIsUnconstrained {
            if ratio > 1.0 {
                return Int(round(imageSize.width))
            }
            return Int(round(imageSize.height))

        } else if widthIsUnconstrained {
            if ratio > 1.0 {
                return Int(imageSize.proportionalWidth(forHeight: self.height, precision: .rounded))
            }
            return Int(round(self.height))

        } else if heightIsUnconstrained {
            if ratio > 1.0 {
                return Int(round(self.width))
            }
            return Int(imageSize.proportionalHeight(forWidth: self.width, precision: .rounded))
        }

        return Int(round(min(self.width, self.height)))
    }

    var maximumPixelSizeConstraint: CGFloat {
        let constrainWidth = width >= 1.0 && width != CGFloat.unconstrained
        let constrainHeight = height >= 1.0 && height != CGFloat.unconstrained
        if constrainWidth && constrainHeight {
            return max(width, height)
        }
        if constrainWidth {
            return width
        }
        if constrainHeight {
            return height
        }
        return 1.0
    }

    func scaledHeight(forImageSize imageSize: CGSize) -> CGFloat {
        return min(imageSize.height, self.height)
    }

    func proportionalWidth(forHeight height: CGFloat, precision: PrecisionScheme) -> CGFloat {
        precision.applied(to: height * self.aspectRatio)
    }
    
    func proportionalHeight(forWidth width: CGFloat, precision: PrecisionScheme) -> CGFloat {
        precision.applied(to: width / self.aspectRatio)
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

        print("\(self) vs. \(targetSize): width \(widthIsSufficient ? "ok" : "👎🏻"), height \(heightIsSufficient ? "ok" : "👎🏻")")

        return widthIsSufficient && heightIsSufficient
    }
}


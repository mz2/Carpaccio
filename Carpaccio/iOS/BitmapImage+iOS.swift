//
//  BitmapImage+iOS.swift
//  Carpaccio
//
//  Created by Matias Piipari on 03/09/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation
import UIKit

extension UIImage:BitmapImage {
    public func name() -> String? {
        return self.accessibilityIdentifier
    }
    
    public func scaled(height: CGFloat, screenScaleFactor: CGFloat) -> BitmapImage
    {
        let cgImage = self.cgImage!
        return UIImage(cgImage: cgImage, scale: height, orientation: self.imageOrientation)
    }
}

struct BitmapImageUtility {
    
    static func image(named name:String) -> BitmapImage? {
        return UIImage(named: name)
    }
    
    static func image(named imageName: String, bundle: Bundle) -> BitmapImage? {
        return UIImage(named: imageName, in: bundle, compatibleWith: nil)
    }
    
    static func image(sized size: CGSize) -> BitmapImage {
        UIGraphicsBeginImageContext(size)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
    static func image(cgImage: CGImage, size: CGSize) -> BitmapImage {
        print("Please check correctness. Most likely this isn't OK as it was only done to get things to compile.")
        
        // this may or may not be wrong – OSX and iOS have a different way of creating an UIImage out of a CGImage:
        // OSX allows for an arbitrary size, iOS only to scale.
        // we don't for our purposes actually really need the arbitrary size behaviour.
        
        return UIImage(cgImage: cgImage,
                       scale: size.width / CGFloat(cgImage.width),
                       orientation: UIImageOrientation.up)
    }
    
    static func image(ciImage image: CIImage) -> BitmapImage? {
        guard let cgImage = image.cgImage else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

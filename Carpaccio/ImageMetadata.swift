//
//  ImageMetadata.swift
//  Carpaccio
//
//  Created by Markus Piipari on 25/07/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//


import Foundation


public struct ImageMetadata
{
    public let aperture: Double
    public let focalLength: Double
    public let ISO: Double
    public let shutterSpeed: NSTimeInterval
    public let size: NSSize
    
    init(size: NSSize, aperture: Double = 0.0, focalLength: Double = 0.0, ISO: Double = 0.0, shutterSpeed: NSTimeInterval = 0.0)
    {
        self.aperture = aperture
        self.size = size
        self.focalLength = focalLength
        self.ISO = ISO
        self.shutterSpeed = shutterSpeed
    }
    
    init(RAWConverterMetadata metadata: [NSObject: AnyObject])
    {
        let aperture = (metadata[RAWConverterMetadataKeyAperture] as? NSNumber)?.doubleValue ?? 0.0
        let focalLength = (metadata[RAWConverterMetadataKeyFocalLength] as? NSNumber)?.doubleValue ?? 0.0
        let ISO = (metadata[RAWConverterMetadataKeyISO] as? NSNumber)?.doubleValue ?? 0.0
        let shutterSpeed = (metadata[RAWConverterMetadataKeyShutterSpeed] as? NSNumber)?.doubleValue ?? 0.0
        
        let w: CGFloat = CGFloat((metadata[RAWConverterMetadataKeyImageWidth] as? NSNumber)?.doubleValue ?? 0.0)
        let h: CGFloat = CGFloat((metadata[RAWConverterMetadataKeyImageHeight] as? NSNumber)?.doubleValue ?? 0.0)
            
        self.init(size: NSSize(width: w, height: h), aperture: aperture, focalLength: focalLength, ISO: ISO, shutterSpeed: shutterSpeed)
    }
    
    public var humanReadableAperture: String {
        get
        {
            // Default to showing one decimal place...
            let oneTenthPrecisionAperture = round(self.aperture * 10.0) / 10.0
            let integerApterture = Int(oneTenthPrecisionAperture)
            
            // ..but avoid displaying .0
            if oneTenthPrecisionAperture == Double(integerApterture) {
                return "f/\(integerApterture)"
            }
            
            return "f/\(oneTenthPrecisionAperture)"
        }
    }
    
    public var humanReadableFocalLength: String {
        get
        {
            let mm = Int(round(self.focalLength))
            return "\(mm)mm"
        }
    }

    public var humanReadableISO: String {
        get
        {
            let ISO = Int(round(self.ISO))
            return "ISO \(ISO)"
        }
    }
    
    public var humanReadableShutterSpeed: String {
        get
        {
            if self.shutterSpeed <= 0.0 {
                return ""
            }
            else if self.shutterSpeed < 1.0
            {
                let dividend = Int(round(1.0 / self.shutterSpeed))
                return "1/\(dividend)"
            }
            
            let oneTenthPrecisionSeconds = round(self.shutterSpeed * 10.0) / 10.0
            return "\(oneTenthPrecisionSeconds)s"
        }
    }
    
    public var humanReadableMetadataSummary: String {
        get {
            return "\(self.humanReadableFocalLength) \(self.humanReadableAperture) \(self.humanReadableShutterSpeed) \(self.humanReadableISO)"
        }
    }
}

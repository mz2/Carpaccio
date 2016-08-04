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
    public let aperture: Double?
    public let cameraMaker: String?
    public let cameraModel: String?
    public let focalLength: Double?
    public let focalLength35mmEquivalent: Double?
    public let ISO: Double?
    public let nativeOrientation: CGImagePropertyOrientation
    public let nativeSize: NSSize
    public let shutterSpeed: NSTimeInterval?
    
    init(nativeSize: NSSize, nativeOrientation: CGImagePropertyOrientation = .Up, aperture: Double? = nil, focalLength: Double? = nil, focalLength35mmEquivalent: Double? = nil, ISO: Double? = nil, shutterSpeed: NSTimeInterval? = nil, cameraMaker: String? = nil, cameraModel: String? = nil)
    {
        self.aperture = aperture
        self.cameraMaker = cameraMaker
        self.cameraModel = cameraModel
        self.focalLength = focalLength
        self.focalLength35mmEquivalent = focalLength35mmEquivalent
        self.ISO = ISO
        self.nativeOrientation = nativeOrientation
        self.nativeSize = nativeSize
        self.shutterSpeed = shutterSpeed
    }
    
    /*
    init(LibRAWConverterMetadata metadata: [NSObject: AnyObject])
    {
        let aperture = (metadata[RAWConverterMetadataKeyAperture] as? NSNumber)?.doubleValue
        let focalLength = (metadata[RAWConverterMetadataKeyFocalLength] as? NSNumber)?.doubleValue
        let ISO = (metadata[RAWConverterMetadataKeyISO] as? NSNumber)?.doubleValue
        let shutterSpeed = (metadata[RAWConverterMetadataKeyShutterSpeed] as? NSNumber)?.doubleValue
        
        let w: CGFloat = CGFloat((metadata[RAWConverterMetadataKeyImageWidth] as? NSNumber)?.doubleValue ?? 0.0)
        let h: CGFloat = CGFloat((metadata[RAWConverterMetadataKeyImageHeight] as? NSNumber)?.doubleValue ?? 0.0)
            
        self.init(nativeSize: NSSize(width: w, height: h), aperture: aperture, focalLength: focalLength, ISO: ISO, shutterSpeed: shutterSpeed)
    }
     */
    
    public var size: NSSize
    {
        let shouldSwapWidthAndHeight: Bool
        
        switch self.nativeOrientation
        {
        case .Left, .Right, .LeftMirrored, .RightMirrored:
            shouldSwapWidthAndHeight = true
        default:
            shouldSwapWidthAndHeight = false
        }
        
        if shouldSwapWidthAndHeight {
            return NSSize(width: self.nativeSize.height, height: self.nativeSize.width)
        }
        
        return self.nativeSize
    }
    
    public var cleanedUpCameraModel: String? {
        get {
            guard let model = self.cameraModel else {
                return nil
            }
            
            let cleanModel = model.stringByReplacingOccurrencesOfString("NIKON", withString: "Nikon")
            return cleanModel
        }
    }
    
    public var humanReadableAperture: String? {
        get
        {
            guard let aperture = self.aperture else {
                return nil
            }
            
            // Default to showing one decimal place...
            let oneTenthPrecisionAperture = round(aperture * 10.0) / 10.0
            let integerApterture = Int(oneTenthPrecisionAperture)
            
            // ..but avoid displaying .0
            if oneTenthPrecisionAperture == Double(integerApterture) {
                return "f/\(integerApterture)"
            }
            
            return "f/\(oneTenthPrecisionAperture)"
        }
    }
    
    public var humanReadableFocalLength: String? {
        get
        {
            guard let f = self.focalLength else {
                return nil
            }
            
            let mm = Int(round(f))
            return "\(mm)mm"
        }
    }
    
    public var humanReadableFocalLength35mmEquivalent: String? {
        get
        {
            guard let f = self.focalLength35mmEquivalent else {
                return nil
            }
            
            let mm = Int(round(f))
            return "\(mm)mm"
        }
    }

    public var humanReadableISO: String? {
        get
        {
            guard let ISO = self.ISO else {
                return nil
            }
            
            let integerISO = Int(round(ISO))
            return "ISO \(integerISO)"
        }
    }
    
    public var humanReadableShutterSpeed: String? {
        get
        {
            guard let s = self.shutterSpeed else {
                return nil
            }
            
            if s <= 0.0 {
                return nil
            }
            else if s < 1.0
            {
                let dividend = Int(round(1.0 / s))
                return "1/\(dividend)"
            }
            
            let oneTenthPrecisionSeconds = round(s * 10.0) / 10.0
            return "\(oneTenthPrecisionSeconds)s"
        }
    }
    
    public var humanReadableMetadataSummary: String {
        get {
            return "\(padTail(ofString:self.cleanedUpCameraModel))\(padTail(ofString: self.humanReadableFocalLength))\(padTail(ofString: conditional(string:"(\(self.humanReadableFocalLength35mmEquivalent))", condition: (self.focalLength35mmEquivalent != nil && self.focalLength35mmEquivalent != self.focalLength))))\(padTail(ofString: self.humanReadableAperture))\(padTail(ofString: self.humanReadableShutterSpeed))\(padTail(ofString: self.humanReadableISO))"
        }
    }
}

func conditional(string s: String?, condition: Bool) -> String?
{
    if condition {
        return s
    }
    return nil
}

func padTail(ofString s: String?, with: String = " ") -> String
{
    if let s = s {
        if !s.isEmpty {
            return "\(s)\(with)"
        }
    }
    return ""
}

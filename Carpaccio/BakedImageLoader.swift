
//
//  ImageIO.swift
//  Carpaccio
//
//  Created by Markus Piipari on 27/07/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//


import Foundation
import ImageIO

/*
CFDictionary P2CreateDictionary(CFString *keys, CFType* values, const int n)
{
    CFDictionary dictionary = CFDictionaryCreate(NULL,
                                                    (const void **)keys,
                                                    (const void **)values,
                                                    n,
                                                    &kCFTypeDictionaryKeyCallBacks,
                                                    &kCFTypeDictionaryValueCallBacks
    );
    return dictionary;
}

CFError P2CreateError(CFString domain, CFIndex code, CFString localizedDescription)
{
    static const int n = 1;
    CFString keys[n];
    CFType values[n];
    
    keys[0] = kCFErrorLocalizedDescriptionKey;
    values[0] = localizedDescription;
    
    CFDictionary userInfo = P2CreateDictionary(keys, values, n);
    
    CFError error = CFErrorCreate(NULL, domain, code, userInfo);
    return error;
}
*/

// Mark: - Image metadata

/**
 Create an image metadata object from a dictionary with valid XMP paths as keys, pointing to valid XMP values (of either CFString, CFArray or CFDictionary type.)
 */
/*
public func createImageMetadataWithDictionary(dictionary: CFDictionary, error: CFError) -> CGImageMetadata
{
    let metadata = CGImageMetadataCreateMutable()
    var failed = false
    
    let count = CFDictionaryGetCount(dictionary)
    let keys = calloc(sizeof(void *), count);
    let values = calloc(sizeof(void *), count);
    CFDictionaryGetKeysAndValues(dictionary, (const void **)keys, (const void **)values);
    
    for (CFIndex i = 0; i < count; i++)
    {
        CFType value = NULL;
        Boolean present = CFDictionaryGetValueIfPresent(dictionary, keys[i], &value);
        if (!present)
        continue;
        
        bool success = CGImageMetadataSetValueWithPath(metadata, NULL, keys[i], value);
        
        if (!success)
        {
            if (error)
            {
                CFString description = CFStringCreateWithFormat(NULL, NULL, CFSTR("Failed to set image metadata path '%@' to value %@"), keys[i], value);
                *error = P2CreateError(P2ImageIOErrorDomain, 1, description);
            }
            failed = true;
            break;
        }
    }
    
    // Clean up
    free(keys);
    free(values);
    
    if (failed)
    {
        CFRelease(metadata);
        return NULL;
    }
    
    return metadata;
}
 */

func imageSourceWithURL(URL: NSURL) -> CGImageSource?
{
    // Set up options
    /*let n = 2;
    CFString keys[n];
    CFType values[n];
    
    keys[0] = kCGImageSourceShouldCache;
    values[0] = (CFType)kCFBooleanFalse;
    
    keys[1] = kCGImageSourceShouldAllowFloat;
    values[1] = (CFType)kCFBooleanTrue;
    
    CFDictionary options = P2CreateDictionary(keys, values, n);*/
    
    // Create image source
    let options: CFDictionary = [String(kCGImageSourceShouldCache): false, String(kCGImageSourceShouldAllowFloat): true]
    let source = CGImageSourceCreateWithURL(URL, options);
    return source
}

func imageWithURL(URL: NSURL) -> CGImage?
{
    if let source = imageSourceWithURL(URL)
    {
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        return image
    }
    return nil
}

func thumbnailImageWithImageSource(imageSource: CGImageSource, maximumPixelSize: Int, alwaysCreateFromFullImage: Bool) -> CGImage?
{
    /*static const int n = 3;
    CFString keys[n];
    CFType values[n];
    
    keys[0] = kCGImageSourceCreateThumbnailWithTransform;
    values[0] = (CFType)kCFBooleanTrue;
    
    keys[1] = alwaysCreateFromFullImage ? kCGImageSourceCreateThumbnailFromImageAlways : kCGImageSourceCreateThumbnailFromImageIfAbsent;
    values[1] = (CFType)kCFBooleanTrue;
    
    keys[2] = kCGImageSourceThumbnailMaxPixelSize;
    values[2] = CFNumberCreate(NULL, kCFNumberIntType, &maximumPixelSize);
    
    CFDictionary options = P2CreateDictionary(keys, values, n);*/
    let options: CFDictionary = [String(kCGImageSourceCreateThumbnailWithTransform): true, String(alwaysCreateFromFullImage ? kCGImageSourceCreateThumbnailFromImageAlways : kCGImageSourceCreateThumbnailFromImageIfAbsent): true, String(kCGImageSourceThumbnailMaxPixelSize): maximumPixelSize]
    let thumbnailImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options)
    return thumbnailImage
}

func extractImageMetadata(imageSource imageSource: CGImageSource) -> ImageMetadata?
{
    if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil),
       let EXIFDictionary = NSDictionary(dictionary: properties)[kCGImagePropertyExifDictionary as! NSString]
    {
        let EXIF = NSDictionary(dictionary: EXIFDictionary as! CFDictionary)
        
        let aperture = EXIF[kCGImagePropertyExifApertureValue as! NSString]?.doubleValue ?? 0.0
        let focalLength = EXIF[kCGImagePropertyExifFocalLength as! NSString]?.doubleValue ?? 0.0
        let height = CGFloat(EXIF[kCGImagePropertyExifPixelYDimension as! NSString]?.doubleValue ?? 0.0)
        
        var ISO = 0.0
        if let ISOs = EXIF[kCGImagePropertyExifISOSpeedRatings as! NSString]
        {
            let ISOArray = NSArray(array: ISOs as! CFArray)
            if ISOArray.count > 0 {
                ISO = ISOArray[0].doubleValue
            }
        }
        
        let shutterSpeed = EXIF[kCGImagePropertyExifExposureTime as! NSString]?.doubleValue ?? 0.0
        let width = CGFloat(EXIF[kCGImagePropertyExifPixelXDimension as! NSString]?.doubleValue ?? 0.0)
        
        let metadata = ImageMetadata(size: NSSize(width: width, height: height), aperture: aperture, focalLength: focalLength, ISO: ISO, shutterSpeed: shutterSpeed)
        return metadata
    }
    
    return nil
}

/*
#pragma mark - Image writing

bool P2WriteImageToURL(CGImage image, CFURL URL, const CFString UTI, CFDictionary options)
{
    /*CFString path = CFURLCopyFileSystemPath(URL, kCFURLPOSIXPathStyle);
     CFURL filePathURL = CFURLCreateWithFileSystemPath(NULL, path, kCFURLPOSIXPathStyle, false);
     
     CGImageDestination destination = CGImageDestinationCreateWithURL(filePathURL, UTI, 1, NULL);
     
     CFRelease(path);
     CFRelease(filePathURL);*/
    
    CGImageDestination destination = CGImageDestinationCreateWithURL(URL, UTI, 1, NULL);
    
    if (!destination)
    return false;
    
    CGImageDestinationAddImage(destination, image, options);
    bool success = CGImageDestinationFinalize(destination);
    
    CFRelease(destination);
    
    return success;
}

bool P2WriteJPEGImageToURL(CGImage image, CFURL URL, float compression)
{
    static const int n = 1;
    CFString keys[n];
    CFType values[n];
    
    keys[0] = kCGImageDestinationLossyCompressionQuality;
    values[0] = CFNumberCreate(NULL, kCFNumberFloatType, &compression);
    
    CFDictionary options = P2CreateDictionary(keys, values, n);
    
    bool success = P2WriteImageToURL(image, URL, kUTTypeJPEG, options);
    
    CFRelease(options);
    CFRelease(values[0]);
    
    return success;
}

bool P2WritePNGImageToURL(CGImage image, CFURL URL)
{
    bool success = P2WriteImageToURL(image, URL, kUTTypePNG, NULL);
    return success;
}

bool P2CopyImageContentsAtURLToURLWithMetadata(CFURL sourceURL, CFURL destinationURL, CFDictionary metadataDictionary, bool mergeExistingMetadata, CFError *error)
{
    CGImageSource source = P2CreateImageSourceWithURL(sourceURL);
    assert(source);
    if (!source)
    return false;
    
    CFString UTI = CGImageSourceGetType(source);
    assert(UTI);
    
    CGImageDestination destination = CGImageDestinationCreateWithURL(destinationURL, UTI, 1, NULL);
    assert(destination);
    if (!destination)
    return false;
    
    CGImageDestinationAddImageFromSource(destination, source, 0, NULL);
    
    static const int n = 2;
    CFString keys[n];
    CFType values[n];
    
    CGImageMetadata metadata = P2CreateImageMetadataWithDictionary(metadataDictionary, error);
    if (!metadata)
    return false;
    
    keys[0] = kCGImageDestinationMetadata;
    values[0] = metadata;
    
    keys[1] = kCGImageDestinationMergeMetadata;
    values[1] = (mergeExistingMetadata ? kCFBooleanTrue : kCFBooleanFalse);
    
    CFDictionary options = P2CreateDictionary(keys, values, n);
    
    bool success = CGImageDestinationCopyImageSource(destination, source, options, error);
    assert(success);
    return success;
}*/



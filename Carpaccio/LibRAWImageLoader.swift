//
//  LibRAWImageLoader.swift
//  Carpaccio
//
//  Created by Markus Piipari on 27/07/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Cocoa


public class LibRAWImageLoader: ImageLoaderProtocol
{
    public let imageURL: NSURL

    init(imageURL: NSURL)
    {
        self.imageURL = imageURL
    }
    
    private var _converter: RAWConverter?
    
    private func converter() throws -> RAWConverter
    {
        if let converter = self._converter
        {
            if !converter.isImageDecoded {
                return converter
            }
        }
        
        try self._converter = RAWConverter(URL: self.imageURL)
        
        return self._converter!
    }
    
    public func extractImageMetadata(handler: ImageMetadataHandler, errorHandler: ImageLoadingErrorHandler)
    {
        let converter: RAWConverter
        do {
            converter = try self.converter()
        }
        catch
        {
            errorHandler(error: error)
            return
        }
        
        converter.decodeMetadata({ metadataDictionary in
            
            let metadata = ImageMetadata(RAWConverterMetadata: metadataDictionary)
            handler(metadata: metadata)
            
        }, errorHandler: { error in errorHandler(error: error) })
    }
    
    public func loadThumbnailImage(handler: PresentableImageHandler, errorHandler: ImageLoadingErrorHandler)
    {
        let converter: RAWConverter
        do {
            converter = try self.converter()
        }
        catch
        {
            errorHandler(error: error)
            return
        }
        
        converter.decodeWithThumbnailHandler({ fetchedThumbnail in
            
            let metadata = ImageMetadata(RAWConverterMetadata: converter.metadata!)
            handler(image: fetchedThumbnail, metadata: metadata)
            
        }) { error in errorHandler(error: error) }
    }
    
    public func loadFullSizeImage(handler: PresentableImageHandler, errorHandler: ImageLoadingErrorHandler)
    {
        let converter: RAWConverter
        let URL: NSURL
        
        do
        {
            converter = try self.converter()
            URL = try NSFileManager.defaultManager().URLForDirectory(.CachesDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        }
        catch
        {
            errorHandler(error: error)
            return
        }
        
        converter.decodeToDirectoryAtURL(URL, thumbnailHandler: nil, imageHandler: { (image: NSImage) in

            let metadata = ImageMetadata(RAWConverterMetadata: converter.metadata!)
            handler(image: image, metadata: metadata)
            
            self._converter = nil // Can't reuse LibRAW converter after unpacking & processing have been done
            
            }, imageURLHandler: nil, errorHandler: { error in
                errorHandler(error: error)
                self._converter = nil
            }
        )

    }
}
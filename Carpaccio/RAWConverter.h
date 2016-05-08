//
//  RAWConverter.h
//  Carpaccio
//
//  Created by Matias Piipari on 07/05/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *_Nonnull const RAWConverterErrorDomain;

typedef NS_ENUM(NSUInteger, RAWConversionError) {
    RAWConversionErrorOpenFailed = 1,
    RAWConversionErrorUnpackImageFailed = 2,
    RAWConversionErrorUnpackThumbnailFailed = 3,
    RAWConversionErrorPostprocessingFailed = 4,
    RAWConversionErrorInMemoryThumbnailCreationFailed = 5,
    RAWConversionErrorInMemoryConvertedImageWritingFailed = 6
};

@interface RAWConverter : NSObject

@property (readonly, copy, nonnull) NSURL *URL;
@property (readonly, copy, nonnull) NSURL *convertedImagesRootURL;

typedef void (^RAWConverterThumbnailHandler)(NSImage *_Nonnull image);
typedef void (^RAWConverterImageHandler)(NSURL *_Nonnull convertedURL);

typedef void (^RAWConverterErrorHandler)(NSError *_Nonnull error);

- (nonnull instancetype)initWithURL:(nonnull NSURL *)URL
             convertedImagesRootURL:(nonnull NSURL *)directoryURL;

- (void)decodeContentsOfURL:(nonnull NSURL *)URL
           thumbnailHandler:(nonnull RAWConverterThumbnailHandler)thumbnailHandler
               imageHandler:(nonnull RAWConverterImageHandler)imageHandler
               errorHandler:(nonnull RAWConverterErrorHandler)errorHandler;

@end

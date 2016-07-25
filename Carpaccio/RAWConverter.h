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
    RAWConversionErrorInMemoryFullSizeImageCreationFailed = 6,
    RAWConversionErrorInMemoryConvertedImageWritingFailed = 7,
    RAWConversionErrorDataAtContentsOfURLIsNotAnImage = 8
};

typedef NS_OPTIONS(NSInteger, RAWConverterState) {
    RAWConverterStateOpened = 1,
    RAWConverterStateThumbnailUnpacked = 2,
    RAWConverterStateThumbnailDecodedToMemory = 4,
    RAWConverterStateImageUnpacked = 8,
    RAWConverterStateImageProcessed = 16,
    RAWConverterStateImageWrittenToDisk = 32,
    RAWConverterStateImageDecoded = 64
};

@interface RAWConverter : NSObject

@property (readonly, copy, nonnull) NSURL *URL;
@property (readonly, nullable) NSError *error;
@property (readonly) RAWConverterState state;

typedef void (^RAWConverterImageHandler)(NSImage *_Nonnull image);
typedef void (^RAWConverterImageURLHandler)(NSURL *_Nonnull convertedURL);

typedef void (^RAWConverterErrorHandler)(NSError *_Nonnull error);

- (nullable instancetype)initWithURL:(nonnull NSURL *)URL error:(NSError *_Nullable *_Nullable)error;

- (void)decodeWithThumbnailHandler:(nonnull RAWConverterImageHandler)thumbnailHandler
                      errorHandler:(nonnull RAWConverterErrorHandler)errorHandler;

/** Decode and process full-size image in memory, without writing to temporary directory on disk. */
- (void)decodeWithImageHandler:(nonnull RAWConverterImageHandler)imageHandler
                  errorHandler:(nonnull RAWConverterErrorHandler)errorHandler;

- (void)decodeToDirectoryAtURL:(nonnull NSURL *)convertedImagesRootURL
              thumbnailHandler:(nullable RAWConverterImageHandler)thumbnailHandler
                  imageHandler:(nullable RAWConverterImageHandler)imageHandler
               imageURLHandler:(nullable RAWConverterImageURLHandler)imageURLHandler
                  errorHandler:(nonnull RAWConverterErrorHandler)errorHandler;

@end

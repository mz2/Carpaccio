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
    RAWConversionErrorInMemoryImageCreationFailed = 6
};

@interface RAWConverter : NSObject

typedef void (^RAWConverterImageHandler)(NSImage *_Nonnull image);
typedef void (^RAWConverterErrorHandler)(NSError *_Nonnull error);

- (nonnull instancetype)init;

- (void)decodeContentsOfURL:(nonnull NSURL *)URL
           thumbnailHandler:(nonnull RAWConverterImageHandler)thumbnailHandler
               imageHandler:(nonnull RAWConverterImageHandler)imageHandler
               errorHandler:(nonnull RAWConverterErrorHandler)errorHandler;

@end

//
//  RAWConverter.h
//  Carpaccio
//
//  Created by Matias Piipari on 07/05/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const RAWConverterErrorDomain;

typedef NS_ENUM(NSUInteger, RAWConversionError) {
    RAWConversionErrorOpenFailed = 1,
    RAWConversionErrorUnpackImageFailed = 2,
    RAWConversionErrorUnpackThumbnailFailed = 3,
    RAWConversionErrorPostprocessingFailed = 4
};

@interface RAWConverter : NSObject

typedef void (^RAWConverterImageHandler)(NSImage *image);
typedef void (^RAWConverterErrorHandler)(NSError *error);

- (instancetype)init;

- (void)decodeContentsOfURL:(NSURL *)URL
           thumbnailHandler:(RAWConverterImageHandler)thumbnailHandler
               imageHandler:(RAWConverterImageHandler)imageHandler
               errorHandler:(RAWConverterErrorHandler)errorHandler;

@end

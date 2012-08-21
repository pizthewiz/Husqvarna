//
//  main.m
//  Husqvarna
//
//  Created by Jean-Pierre Mouilleseaux on 15 Aug 2011.
//  Copyright (c) 2011-2012 Chorded Constructions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import "NSURL+CCAdditions.h"

void usage(const char * argv[]);
CGImageRef CreateScaledImageAtFactor(CGImageRef sourceImage, CGFloat scaleFactor);
CFDataRef CreateCompressedJPEGDataFromImage(CGImageRef image, CGFloat compressionFactor);
void runIt(NSURL* source, NSURL* destination, NSUInteger width, NSUInteger height, CGFloat compressionQuality);

void usage(const char * argv[]) {
    printf("usage: %s <source> <destination> <dimensions> <compression> ...\n", [[[NSString stringWithUTF8String:argv[0]] lastPathComponent] UTF8String]);
}
CGImageRef CreateScaledImageAtFactor(CGImageRef sourceImage, CGFloat scaleFactor) {
    size_t sourceWidth = CGImageGetWidth(sourceImage);
    size_t sourceHeight = CGImageGetHeight(sourceImage);
    size_t scaledWidth = floorf(sourceWidth * scaleFactor);
    size_t scaledHeight = floorf(sourceHeight * scaleFactor);

    size_t bytesPerRow = scaledWidth * 4;
    if (bytesPerRow % 16) {
        bytesPerRow = ((bytesPerRow / 16) + 1) * 16;
    }

    CGContextRef bitmapContext = CGBitmapContextCreate(NULL, scaledWidth, scaledHeight, 8, bytesPerRow, CGImageGetColorSpace(sourceImage), kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
    if (!bitmapContext) {
        NSLog(@"ERROR - failed to create bitmap context to rescale image");
        return NULL;
    }

    CGContextScaleCTM(bitmapContext, scaleFactor, scaleFactor);

    CGRect bounds = (CGRect){.size.width = sourceWidth, .size.height = sourceHeight};
    CGContextClearRect(bitmapContext, bounds);
    CGContextDrawImage(bitmapContext, bounds, sourceImage);

    CGImageRef scaledImage = CGBitmapContextCreateImage(bitmapContext);
    CGContextRelease(bitmapContext);

    return scaledImage;
}

CFDataRef CreateCompressedJPEGDataFromImage(CGImageRef image, CGFloat compressionFactor) {
    CFMutableDataRef imageData = CFDataCreateMutable(kCFAllocatorDefault, 0);
    CGImageDestinationRef destination = CGImageDestinationCreateWithData(imageData, kUTTypeJPEG, 1, NULL);
    if (!destination) {
        NSLog(@"ERROR - failed to create in-memory image destination");
        CFRelease(imageData);
        return NULL;
    }
    // set JPEG compression
    NSDictionary* properties = @{(id)kCGImageDestinationLossyCompressionQuality: @(compressionFactor)};
    CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)properties);
    BOOL status = CGImageDestinationFinalize(destination);
    if (!status) {
        NSLog(@"ERROR - failed to write scaled image to in-memory buffer");
        CFRelease(imageData);
        CFRelease(destination);
        return NULL;
    }
    CFRelease(destination);

    return (CFDataRef)imageData;
}
void runIt(NSURL* sourceFileURL, NSURL* outputFileURL, NSUInteger outputWidth, NSUInteger outputHeight, CGFloat compressionQuality) {
    NSError* error = nil;
    NSData* imageData = [[NSData alloc] initWithContentsOfURL:sourceFileURL options:0 error:&error];
    if (!imageData) {
        NSLog(@"ERROR - failed to read image %@", [error localizedDescription]);
        exit(1);
    }

    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    if (!imageSource) {
        NSLog(@"ERROR - failed to crate image source");
    }
    CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, 0, NULL);
    if (!image) {
        NSLog(@"ERROR - failed to crate image from source");
    }
    if (imageSource)
        CFRelease(imageSource);

    CGFloat scaleFactor = MAX((CGFloat)outputWidth/CGImageGetWidth(image), (CGFloat)outputHeight/CGImageGetHeight(image));
    CGImageRef scaledImage = CreateScaledImageAtFactor(image, scaleFactor);
    NSLog(@"resized image %lux%lu", CGImageGetWidth(scaledImage), CGImageGetHeight(scaledImage));
    CGImageRelease(image);

    // grab JPEG compressed data from image
    CFDataRef compressedImageData = CreateCompressedJPEGDataFromImage(scaledImage, compressionQuality);
    CGImageRelease(scaledImage);

    imageData = (__bridge_transfer NSData*)compressedImageData;
    BOOL status = [imageData writeToURL:outputFileURL atomically:YES];
    if (!status) {
        NSLog(@"ERROR - failed to write compressed image to disk");
        exit(1);
    }
}



int main (int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 5 || (argc-2) % 3) {
            usage(argv);
            exit(1);
        }

        NSLog(@"%@", [NSString stringWithUTF8String:argv[0]]);

        NSString* sourceFileLocation = [NSString stringWithUTF8String:argv[1]];
        NSURL* sourceFileURL = [NSURL fileURLWithString:sourceFileLocation];
//        NSLog(@"sourceFileURL: %@", sourceFileURL);

        NSError* error;
        if (![sourceFileURL checkResourceIsReachableAndReturnError:&error]) {
            NSLog(@"ERROR - bad source image url: %@", [error localizedDescription]);
            exit(1);
        }

        for (NSUInteger argIndex = 2; argIndex < argc;) {
            NSString* outputFileLocation = [NSString stringWithUTF8String:argv[argIndex++]];
            NSURL* outputFileURL = [[NSURL alloc] initFileURLWithPossiblyRelativePath:outputFileLocation isDirectory:NO];
            NSLog(@"outputFileURL: %@", outputFileURL);
            if ([outputFileURL checkResourceIsReachableAndReturnError:NULL]) {
                NSLog(@"will overwrite: %@", outputFileURL);
            }

            // create intermediate directories when necessary
            NSURL* baseDirectory = [outputFileURL URLByDeletingLastPathComponent];
            if (![baseDirectory checkResourceIsReachableAndReturnError:NULL]) {
                NSLog(@"attempting to create base directory: %@", baseDirectory);
                NSError* error;
                BOOL success = [[NSFileManager defaultManager] createDirectoryAtURL:baseDirectory withIntermediateDirectories:YES attributes:nil error:&error];
                if (!success) {
                    NSLog(@"ERROR - failed to create base directory %@ - %@", baseDirectory, [error localizedDescription]);
                    exit(1);
                }
            }

            NSString* outputDimensions = [NSString stringWithUTF8String:argv[argIndex++]];
            NSLog(@"outputDimensions: %@", outputDimensions);

            NSSize size = outputDimensions ? NSSizeFromString(outputDimensions) : NSZeroSize;
            if (NSEqualSizes(size, NSZeroSize)) {
                NSLog(@"ERROR - bad output size provided '%@' should be WxH", outputDimensions);
            }
            NSUInteger outputWidth = (NSUInteger)size.width;
            NSUInteger outputHeight = (NSUInteger)size.height;
            NSLog(@"width: %lu, height: %lu", outputWidth, outputHeight);

            NSString* compressionString = [NSString stringWithUTF8String:argv[argIndex++]];
            CGFloat compressionQuality = [compressionString floatValue];
            NSLog(@"compressionQuality: %f", compressionQuality);

            runIt(sourceFileURL, outputFileURL, outputWidth, outputHeight, compressionQuality);
        }
    }
    return 0;
}

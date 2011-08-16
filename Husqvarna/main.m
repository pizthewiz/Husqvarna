//
//  main.m
//  Husqvarna
//
//  Created by Jean-Pierre Mouilleseaux on 15 Aug 2011.
//  Copyright (c) 2011 Chorded Constructions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import "NSURL+CCAdditions.h"

void dumpUsage(void);
CGImageRef CreateScaledImageAtFactor(CGImageRef sourceImage, CGFloat scaleFactor);
CFDataRef CreateCompressedJPEGDataFromImage(CGImageRef image, CGFloat compressionFactor);
void runIt(NSURL* source, NSURL* destination, NSUInteger width, NSUInteger height);

void dumpUsage(void) {
    NSLog(@"Husqvarna SOURCE_FILE_LOCATION OUTPUT_FILE_LOCATION OUTPUT_SETTINGS [...]");
}
CGImageRef CreateScaledImageAtFactor(CGImageRef sourceImage, CGFloat scaleFactor) {
    CGFloat sourceWidth = CGImageGetWidth(sourceImage);
    CGFloat sourceHeight = CGImageGetHeight(sourceImage);
    CGFloat scaledWidth = floorf(sourceWidth * scaleFactor);
    CGFloat scaledHeight = floorf(sourceHeight * scaleFactor);

    size_t bytesPerRow = scaledWidth * 4;
    if (bytesPerRow % 16)
        bytesPerRow = ((bytesPerRow / 16) + 1) * 16;

    void* baseAddress = valloc(scaledHeight * bytesPerRow);
    if (baseAddress == NULL) {
        NSLog(@"ERROR - failed to valloc memory for bitmap");
        return NULL;
    }

    CGContextRef bitmapContext = CGBitmapContextCreate(baseAddress, scaledWidth, scaledHeight, 8, bytesPerRow, CGImageGetColorSpace(sourceImage), kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host);
    if (bitmapContext == NULL) {
        free(baseAddress);
        return NULL;
    }

    CGContextScaleCTM(bitmapContext, scaleFactor, scaleFactor);

    CGRect bounds = CGRectMake(0., 0., sourceWidth, sourceHeight);
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
    NSDictionary* properties = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithFloat:compressionFactor], kCGImageDestinationLossyCompressionQuality, nil];
    CGImageDestinationAddImage(destination, image, (__bridge_retained CFDictionaryRef)properties);
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
void runIt(NSURL* sourceFileURL, NSURL* outputFileURL, NSUInteger outputWidth, NSUInteger outputHeight) {
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
    CFDataRef compressedImageData = CreateCompressedJPEGDataFromImage(scaledImage, 0.5);
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
        if (argc < 4 || argc % 2) {
            dumpUsage();
            exit(1);
        }

        NSString* sourceFileLocation = [NSString stringWithUTF8String:argv[1]];
        NSURL* sourceFileURL = [NSURL fileURLWithString:sourceFileLocation];
//        NSLog(@"sourceFileURL: %@", sourceFileURL);

        NSError* error;
        if (![sourceFileURL checkResourceIsReachableAndReturnError:&error]) {
            NSLog(@"ERROR - bad source image url: %@", [error localizedDescription]);
            exit(1);
        }

        for (NSUInteger argIndex = 2; argIndex < argc; argIndex += 2) {
            NSString* outputFileLocation = [NSString stringWithUTF8String:argv[argIndex]];
            NSURL* outputFileURL = [NSURL fileURLWithString:outputFileLocation];
            NSLog(@"outputFileURL: %@", outputFileURL);
            if ([outputFileURL checkResourceIsReachableAndReturnError:NULL]) {
                NSLog(@"will overwrite: %@", outputFileURL);
            }

            NSString* outputSettings = [NSString stringWithUTF8String:argv[argIndex+1]];
            NSLog(@"outputSettings: %@", outputSettings);
            NSArray* components = [[outputSettings lowercaseString] componentsSeparatedByString:@"x"];
            if (components.count != 2) {
                NSLog(@"ERROR - bad output size provided '%@' should be WxH", outputSettings);
            }
            NSUInteger outputWidth = [[components objectAtIndex:0] integerValue];
            NSUInteger outputHeight = [[components objectAtIndex:1] integerValue];

            NSLog(@"width: %lu, height: %lu", outputWidth, outputHeight);

            runIt(sourceFileURL, outputFileURL, outputWidth, outputHeight);
        }
    }
    return 0;
}

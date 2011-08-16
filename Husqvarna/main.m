//
//  main.m
//  Husqvarna
//
//  Created by Jean-Pierre Mouilleseaux on 15 Aug 2011.
//  Copyright (c) 2011 Chorded Constructions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSURL+CCAdditions.h"

void dumpUsage(void);

void dumpUsage(void) {
    NSLog(@"Husqvarna SOURCE_FILE OUTPUT_FILE SETTINGS [...]");
}

int main (int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc < 4) {
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

        NSString* outputFileLocation = [NSString stringWithUTF8String:argv[2]];
        NSURL* outputFileURL = [NSURL fileURLWithString:outputFileLocation];
        NSLog(@"outputFileURL: %@", outputFileURL);
        if ([outputFileURL checkResourceIsReachableAndReturnError:NULL]) {
            NSLog(@"will overwrite: %@", outputFileURL);
        }

        NSString* outputSettings = [NSString stringWithUTF8String:argv[3]];
        NSLog(@"outputSettings: %@", outputSettings);
        NSArray* components = [[outputSettings lowercaseString] componentsSeparatedByString:@"x"];
        if (components.count != 2) {
            NSLog(@"ERROR - bad output size provided '%@' should be WxH", outputSettings);
        }
        NSUInteger outputWidth = [[components objectAtIndex:0] integerValue];
        NSUInteger outputHeight = [[components objectAtIndex:1] integerValue];

        NSLog(@"width: %lu, height: %lu", outputWidth, outputHeight);
    }
    return 0;
}

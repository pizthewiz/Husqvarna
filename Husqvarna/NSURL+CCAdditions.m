//
//  NSURL+CCAdditions.m
//  Husqvarna
//
//  Created by Jean-Pierre Mouilleseaux on 15 Aug 2011.
//  Copyright (c) 2011 Chorded Constructions. All rights reserved.
//

#import "NSURL+CCAdditions.h"

@implementation NSURL(CCAdditions)

+ (id)fileURLWithString:(NSString*)string {
    return [[self class] fileURLWithString:string relativeToURL:nil];
}

+ (id)fileURLWithString:(NSString*)string relativeToURL:(NSURL*)baseURL {
    NSURL* url = [NSURL URLWithString:string];
    if (![url isFileURL]) {
        NSString* path = [string stringByStandardizingPath];
        if ([path isAbsolutePath]) {
            url = [NSURL fileURLWithPath:path isDirectory:NO];
        } else if (baseURL) {
//            url = [baseURL URLByAppendingPathComponent:path];
            path = [[[baseURL path] stringByAppendingPathComponent:string] stringByStandardizingPath];
            url = [NSURL URLWithString:path];
        }
    }

    if (![url isFileURL]) {
        url = nil;
    }

    return url;
}

@end

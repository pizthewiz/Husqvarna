//
//  NSURL+CCAdditions.h
//  Husqvarna
//
//  Created by Jean-Pierre Mouilleseaux on 15 Aug 2011.
//  Copyright (c) 2011 Chorded Constructions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL(CCAdditions)
+ (id)fileURLWithString:(NSString*)string;
+ (id)fileURLWithString:(NSString*)string relativeToURL:(NSURL*)baseURL;
- (id)initFileURLWithPossiblyRelativePath:(NSString*)path isDirectory:(BOOL)isDir;
@end

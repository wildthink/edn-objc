//
//  WTEDNReader.h
//  edn-objc
//
//  Created by Jason Jobe on 12/10/14.
//  Copyright (c) 2014 Ben Mosher. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, WTEDNReaderOptions) {
    WTEDNReaderMultipleObjects = (1UL << 0),
    // lazy parsing implies multiple objects
    WTEDNReaderLazyParsing = (1UL << 1),
    WTEDNReaderStrict = (1UL << 2),
    WTEDNReaderDebug = (1UL << 4)       // Wraps tokens to provide lineno
};


@interface WTEDNReader : NSObject

@property (readonly) id root;
@property (nonatomic) WTEDNReaderOptions options;

+ readString:(NSString*)str error:(NSError **)error;
+ readData:(NSData*)data error:(NSError **)error;

- (instancetype)initWithString:(NSString*)str;
- initWithData:(NSData*)data;

- read;

@end

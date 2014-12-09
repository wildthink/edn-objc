//
//  BMOEDNReader.h
//  edn-objc
//
//  Created by Ben Mosher on 8/28/13.
//  Copyright (c) 2013 Ben Mosher. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BMOEDNError.h"
#import "BMOEDNSerialization.h"

@interface BMOEDNReader : NSObject

-(instancetype)initWithOptions:(BMOEDNReadingOptions)options;

-(id)parse:(NSData *)data error:(NSError **)error;
-(id)parseStream:(NSInputStream *)data error:(NSError **)error;

@end

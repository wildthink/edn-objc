//
//  BMOEDNSymbol.h
//  edn-objc
//
//  Created by Ben Mosher on 8/25/13.
//  Copyright (c) 2013 Ben Mosher. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BMOEDNSymbol : NSObject <NSCopying>

@property (strong, nonatomic, readonly) NSString *ns;
@property (strong, nonatomic, readonly) NSString *name;

-(instancetype)initWithNamespace:(NSString *)ns
                            name:(NSString *)name;

+(instancetype)symbolWithNamespace:(NSString *)ns
                                name:(NSString *)name;

-(BOOL)isKeyword;

-(BOOL)isEqualToSymbol:(BMOEDNSymbol *)object;

-(Class)asClassDesignation;

@end

@interface BMOEDNKeyword : BMOEDNSymbol

//+(BMOEDNKeyword *) keywordWithNamespace:(NSString *)ns name:(NSString *)name;
//+(BMOEDNKeyword *) keywordWithName:(NSString *)name;

//-(BOOL)isEqualToKeyword:(BMOEDNKeyword *)object;

@end

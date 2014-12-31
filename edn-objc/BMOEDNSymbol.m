//
//  BMOEDNSymbol.m
//  edn-objc
//
//  Created by Ben Mosher on 8/25/13.
//  Copyright (c) 2013 Ben Mosher. All rights reserved.
//

#import "BMOEDNSymbol.h"

@implementation BMOEDNSymbol

-(instancetype)initWithNamespace:(NSString *)ns
                            name:(NSString *)name {
    if (name == nil) @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"Symbol name must not be nil." userInfo:nil];
    
    if (self = [super init]) {
        _ns = ns;
        _name = name;
    }
    return self;
}

-(BOOL)isKeyword {
    return NO;
}

+(instancetype)symbolWithNamespace:(NSString *)ns name:(NSString *)name {
    return [[self alloc] initWithNamespace:ns name:name];
}

- (Class)asClassDesignation;
{
    return Nil;
}

-(BOOL)isEqual:(id)object {
    if (object == self) return true;
    if (![object isMemberOfClass:[self class]]) return false;
    return [self isEqualToSymbol:(BMOEDNSymbol *)object];
}

-(BOOL)isEqualToSymbol:(BMOEDNSymbol *)object {
    return (self.ns == object.ns || [self.ns isEqualToString:object.ns])
        && [self.name isEqualToString:object.name];
}

-(NSUInteger)hash {
    return ([self.ns hash] * 33) ^ [self.name hash];
}

-(NSString *)description {
    if (self.ns == nil) return [self.name description];
    else return [NSString stringWithFormat:@"%@/%@",self.ns,self.name];
}

-(id)copyWithZone:(NSZone *)zone {
    return self;
}

@end



@implementation BMOEDNKeyword

//+(BMOEDNKeyword *)keywordWithNamespace:(NSString *)ns name:(NSString *)name {
//    return [[self alloc] initWithNamespace:ns name:name];
//}

//+(BMOEDNKeyword *)keywordWithName:(NSString *)name {
//    return [[self alloc] initWithNamespace:nil name:name];
//}

-(BOOL)isKeyword {
    return YES;
}

/*
-(BOOL)isEqual:(id)object {
    if (object == self) return YES;
    if (![object isMemberOfClass:[BMOEDNKeyword class]]) return NO;
    return [self isEqualToKeyword:(BMOEDNKeyword *)object];
}

-(BOOL)isEqualToKeyword:(BMOEDNKeyword *)object {
    return [super isEqualToSymbol:object];
}

-(NSString *)description {
    return [@":" stringByAppendingString:[super description]];
}
*/

@end

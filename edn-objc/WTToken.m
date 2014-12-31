//
//  WTToken.m
//  edn-objc
//
//  Created by Jason Jobe on 12/10/14.
//  Copyright (c) 2014 Ben Mosher. All rights reserved.
//

#import "WTToken.h"

@implementation WTToken

+ (instancetype)tokenFor:(NSObject*)representedObject;
{
    WTToken *token = [WTToken new];
    token.representedObject = representedObject;
    return token;
}

- (BOOL)isToken {
    return YES;
}

- (NSString*)description {
    return [NSString stringWithFormat:@"<%ld %ld>%@", (long)self.lineno, (long)self.column, [self.representedObject description]];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<TOKEN %ld %ld>%@", (long)self.lineno, (long)self.column, [self.representedObject description]];
}

#pragma mark Forwarding machinery

- (Class)class {
    return [self.representedObject class];
}

- (id)forwardingTargetForSelector:(SEL)aSelector {
    return self.representedObject;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [self.representedObject methodSignatureForSelector:selector];
}

- (BOOL)respondsToSelector:(SEL)selector {
    // behave like nil
    return NO;
}

#pragma mark NSObject protocol

- (BOOL)conformsToProtocol:(Protocol *)aProtocol {
    return [self.representedObject conformsToProtocol:aProtocol];
}

- (NSUInteger)hash {
    return [self.representedObject hash];
}

- (BOOL)isEqual:(id)obj {
    return [self.representedObject isEqual:obj];
}

- (BOOL)isKindOfClass:(Class)class {
    return [self.representedObject isKindOfClass:class];
}

- (BOOL)isMemberOfClass:(Class)class {
    return [self.representedObject isMemberOfClass:class];
}

@end

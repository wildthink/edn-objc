//
//  WTToken.h
//  edn-objc
//
//  Created by Jason Jobe on 12/10/14.
//  Copyright (c) 2014 Ben Mosher. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WTToken : NSObject <NSObject>

@property (nonatomic) NSInteger lineno;
@property (nonatomic) NSInteger column;

@property (nonatomic) NSInteger position;
@property (nonatomic) NSInteger length;

@property (nonatomic, strong) NSObject *representedObject;


+ (instancetype)tokenFor:(NSObject*)representedObject;

- (BOOL)isToken;

@end

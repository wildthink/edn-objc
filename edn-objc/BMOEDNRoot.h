//
//  BMOEDNRoot.h
//  edn-objc
//
//  Created by Ben Mosher on 8/31/13.
//  Copyright (c) 2013 Ben Mosher. All rights reserved.
//
//  Supports round-trip serialization of multiple objects without a single
//  top-level root object (such as a Clojure source file).
//
//  Must not be present anywhere but at the root of an edn object graph.

#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
/**
 If the underlying element collection is not an NSArray, it will be
 copied into a buffer as it is enumerated. 
 */
@interface BMOEDNRoot : NSObject<NSFastEnumeration> {
    NSEnumerator * _enumerator;
    NSArray *_realized;
    dispatch_queue_t _realizationQueue;
    unsigned long mutationMarker;
}

-(instancetype)initWithEnumerator:(NSEnumerator *)enumerator;
-(instancetype)initWithArray:(NSArray *)array;

/**
 Array-style index and subscripting support.
 */
-(id)objectAtIndex:(NSUInteger)idx;
-(id)objectAtIndexedSubscript:(NSUInteger)idx;

/**
 Use this guy (vs. fast enumeration) for one-by-one laziness.
 */
//-(NSEnumerator *) objectEnumerator;

@end


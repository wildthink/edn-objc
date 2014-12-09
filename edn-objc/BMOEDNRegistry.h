//
//  BMOEDNRegistry.h
//  edn-objc
//
//  Created by Ben Mosher on 8/30/13.
//  Copyright (c) 2013 Ben Mosher. All rights reserved.
//
//  Register a class during load time (pre-`main` execution)
//  to ensure all de/serialization properly binds.

#import <Foundation/NSObjCRuntime.h>
@class BMOEDNSymbol;

/**
 Register a class that conforms to BMOEDNRepresentation. 
 Should be safe to call during +load. Will use
 the +ednTag symbol as the tag.
 If the provided class does not conform to BMOEDNRepresentation,
 the invocation is a no-op.
 */
void BMOEDNRegisterClass(Class clazz);

/**
 Returns class object currently registered for given
 tag. Nil if tag is currently unregistered.
 */
Class BMOEDNRegisteredClassForTag(BMOEDNSymbol *tag);


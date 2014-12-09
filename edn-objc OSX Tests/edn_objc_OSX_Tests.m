//
//  edn_objc_OSX_Tests.m
//  edn-objc OSX Tests
//
//  Created by Jason Jobe on 12/9/14.
//  Copyright (c) 2014 Ben Mosher. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "edn-objc.h"
#import "BMOLazyEnumerator.h"

#import "NSCodingFoo.h"
#import "NSCodingBar.h"

@interface edn_objc_OSX_Tests : XCTestCase

@end

@implementation edn_objc_OSX_Tests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testParseStrings
{
    XCTAssertEqualObjects([@"\"whee\"" ednObject], @"whee", @"");
    XCTAssertEqualObjects([@"\"I have a \\\"mid-quoted\\\" string in me.\\nAnd two lines.\\r\\nWindows file: \\\"C:\\\\a file.txt\\\"\"" ednObject],
                          @"I have a \"mid-quoted\" string in me.\nAnd two lines.\r\nWindows file: \"C:\\a file.txt\"", @"");
    XCTAssertEqualObjects([@"\"\\\\\\\"\"" ednObject], @"\\\"", @"Backslash city.");
}

- (void)testParseLiterals
{
    XCTAssertEqual([@"true" ednObject], (__bridge NSNumber *)kCFBooleanTrue, @"");
    XCTAssertEqual([@"false" ednObject], (__bridge NSNumber *)kCFBooleanFalse, @"");
    XCTAssertEqualObjects([@"nil" ednObject], [NSNull null], @"");
}

- (void)testParseNumerals
{
    XCTAssertEqualObjects([@"0" ednObject], [NSNumber numberWithInt:0], @"");
    XCTAssertEqualObjects([@"1.1E1" ednObject], [NSNumber numberWithDouble:11.0], @"");
    XCTAssertEqualObjects([@"-2" ednObject], @(-2), @"");
    XCTAssertEqualObjects([@"+0" ednObject], @(0), @"");
    XCTAssertEqualObjects([@"-0" ednObject], @(0), @"");
    XCTAssertEqualObjects([@"0" ednObject], @(0), @"");
    XCTAssertEqualObjects([@"10000N" ednObject], @(10000), @"");
    XCTAssertEqualObjects([@"1000.1M" ednObject], [NSDecimalNumber decimalNumberWithMantissa:10001 exponent:-1 isNegative:NO], @"");
    XCTAssertEqualObjects([@"1/2" ednObject], [BMOEDNRatio ratioWithNumerator:1 denominator:2], @"");
}

- (void) testRatio {
    BMOEDNRatio *r = [BMOEDNRatio ratioWithNumerator:1 denominator:2];
    XCTAssertEqual(r.numerator, 1, @"bad numerator");
    XCTAssertEqual(r.denominator, 2, @"bad denominator");
    XCTAssertEqualObjects(r, @(0.5), @"bad value");
}

- (void) testRatioStrictMode {
    NSError *err = nil;
    XCTAssertNil([BMOEDNSerialization ednObjectWithData:[@"1/2" dataUsingEncoding:NSUTF8StringEncoding] options:BMOEDNReadingStrict error:&err], @"should not parse in strict mode");
    XCTAssertNotNil(err, @"");
    XCTAssertEqual((BMOEDNError)err.code, BMOEDNErrorInvalidData, @"should have return invalid data error");
}

- (void)testCMathWorksHowIExpect
{
    // word on the street is that NSIntegers are converted to NSUInteger
    // during comparison/arithmetic; if overflow wraps, the conversion
    // should not impact addition
    XCTAssertEqual(NSUIntegerMax+((NSInteger)-1), NSUIntegerMax-1, @"");
}

- (void)testParseVectors
{
    XCTAssertEqualObjects([@"[]" ednObject], @[], @"");
    XCTAssertEqualObjects([@"[ 1 ]" ednObject], @[@1], @"");
    id array = @[@1, @2];
    XCTAssertEqualObjects([@"[ 1 2 ]" ednObject], array, @"");
    array = @[@[@1, @2], @[@3], @[]];
    XCTAssertEqualObjects([@"[ [ 1, 2 ], [ 3 ], [] ]" ednObject], array, @"");
}

- (void)testParseLists
{
    BMOEDNList *list = (BMOEDNList *)[@"()" ednObject];
    XCTAssertTrue([list isKindOfClass:[BMOEDNList class]], @"");
    XCTAssertNil([list head], @"");
    
    list = (BMOEDNList *)[[@"[( 1 2 3 4 5 ) 1]" ednObject] objectAtIndex:0];
    XCTAssertTrue([list isKindOfClass:[BMOEDNList class]], @"");
    XCTAssertNotNil([list head], @"");
    BMOEDNConsCell *current = list.head;
    int i = 1;
    do {
        XCTAssertEqualObjects(current.first,@(i++), @"");
    } while ((current = current.rest) != nil);
    
    id<NSObject> secondList = [@"( 1 2 3 4 5 )" ednObject];
    XCTAssertEqualObjects(list, secondList, @"");
    XCTAssertEqual(list.hash, secondList.hash, @"");
}

- (void)testComments
{
    id array = @[@1, @2];
    XCTAssertEqualObjects([@"[ 1 ;; mid-array comment\n 2 ]" ednObject], array, @"");
    XCTAssertEqualObjects([@"[ 1;3\n2 ]" ednObject], array, @"");
}

- (void)testDiscards
{
    id array = @[@1, @2];
    XCTAssertEqualObjects([@"[ 1 #_ foo 2 ]" ednObject], array, @"");
    XCTAssertEqualObjects([@"[ 1 2 #_foo ]" ednObject], array, @"");
    NSError *err = nil;
    id obj = [BMOEDNSerialization ednObjectWithData:[@"  #_fooooo  " dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&err];
    XCTAssertNil(obj, @"");
    // TODO: error for totally empty string?
    //STAssertNotNil(err, @"");
    //STAssertEquals(err.code, (NSInteger)BMOEDNErrorNoData, @"");
    
    BMOEDNList *list = (BMOEDNList *)[@"( 1 #_foo 2 3 4 5 #_bar)" ednObject];
    XCTAssertTrue([list isKindOfClass:[BMOEDNList class]], @"");
    XCTAssertNotNil([list head], @"");
    BMOEDNConsCell *current = list.head;
    int i = 1;
    do {
        XCTAssertEqualObjects(current.first,@(i++), @"");
    } while ((current = current.rest) != nil);
}

- (void)testSets
{
    XCTAssertEqualObjects([@"#{}" ednObject], [NSSet setWithArray:@[]], @"");
    XCTAssertEqualObjects([@"#{ 1 }" ednObject], [NSSet setWithArray:@[@1]], @"");
    id set = [NSSet setWithArray:@[@1, @2]];
    XCTAssertEqualObjects([@"#{ 1 2 }" ednObject], set, @"");
    XCTAssertNil([@"#{ 1 1 2 3 5 }" ednObject], @"Repeated set members should fail.");
}

- (void)testMaps
{
    id map = @{
               @"one":@(1),
               [@"( 1 2 )" ednObject]:@"two",
               @"three":@"surprise!"};
    XCTAssertEqualObjects([@"{\"one\" 1 ( 1 2 ) \"two\" \"three\" \"surprise!\"}" ednObject], map, @"");
    
    XCTAssertEqualObjects([@"{ :one one :two + :three - :four \"four\" }" ednObject],
                          (@{
                             [@":one" ednObject]: [@"one" ednObject],
                             [@":two" ednObject]: [[BMOEDNSymbol alloc] initWithNamespace:nil name:@"+"],
                             [@":three" ednObject]: [[BMOEDNSymbol alloc] initWithNamespace:nil name:@"-"],
                             [@":four" ednObject]: @"four"
                             }), @"");
    XCTAssertNil([@"{:one 1 :one \"one\"}" ednObject],@"Repeat keys should fail.");
}

- (void)testStringCategory {
    XCTAssertEqualObjects([@"\"string\"" ednObject], @"string", @"");
    XCTAssertEqualObjects([@"[ 1 2 3 ]" ednObject], (@[(@1),(@2),(@3)]), @"");
}

- (void)testKeywords
{
    XCTAssertEqualObjects([@":keyword" ednObject], [[BMOEDNKeyword alloc] initWithNamespace:nil name:@"keyword"], @"");
    XCTAssertEqualObjects([@":keyword" ednObject], [BMOEDNKeyword keywordWithName:@"keyword"], @"");
    XCTAssertEqualObjects([@":namespaced/keyword" ednObject], [[BMOEDNKeyword alloc] initWithNamespace:@"namespaced" name:@"keyword"], @"");
    id keyword;
    XCTAssertThrows(keyword = [[BMOEDNKeyword alloc] initWithNamespace:@"something" name:nil], @"");
    XCTAssertNil([@":" ednObject],@"");
    XCTAssertNil([@":/nonamespace" ednObject], @"");
    XCTAssertNil([@":so/many/names/paces" ednObject], @"");
    XCTAssertFalse([[@":keywordsymbol" ednObject] isEqual:[@"keywordsymbol" ednObject]], @"");
    XCTAssertFalse([[@"symbolkeyword" ednObject] isEqual:[@":symbolkeyword" ednObject]], @"");
}

- (void)testSymbols
{
    XCTAssertEqualObjects([@"symbol" ednObject], [[BMOEDNSymbol alloc] initWithNamespace:nil name:@"symbol"], @"");
    XCTAssertEqualObjects([@"namespaced/symbol" ednObject], [[BMOEDNSymbol alloc] initWithNamespace:@"namespaced" name:@"symbol"], @"");
    id symbol;
    XCTAssertThrows(symbol = [[BMOEDNSymbol alloc] initWithNamespace:@"something" name:nil], @"");
    XCTAssertNil([@"/nonamespace" ednObject], @"");
    XCTAssertNil([@"so/many/names/paces" ednObject], @"");
    // '/' is a special case...
    XCTAssertEqualObjects([@"/" ednObject], [[BMOEDNSymbol alloc] initWithNamespace:nil name:@"/"], @"");
    XCTAssertEqualObjects([@"foo//" ednObject], [[BMOEDNSymbol alloc] initWithNamespace:@"foo" name:@"/"], @"");
    
    XCTAssertEqualObjects([@"namespaced/<" ednObject], [[BMOEDNSymbol alloc] initWithNamespace:@"namespaced" name:@"<"], @"");
    XCTAssertEqualObjects([@"namespaced/>" ednObject], [[BMOEDNSymbol alloc] initWithNamespace:@"namespaced" name:@">"], @"");
    XCTAssertEqualObjects([@"html/<body>" ednObject], [[BMOEDNSymbol alloc] initWithNamespace:@"html" name:@"<body>"], @"");
    XCTAssertNil([@"html/</body>" ednObject], @"");
}

- (void)testDeserializeUuidTag
{
    NSUUID *uuid = [NSUUID UUID];
    XCTAssertEqualObjects(([[NSString stringWithFormat:@"#uuid \"%@\"",uuid.UUIDString] ednObject]), uuid, @"");
}

- (void)testDeserializeInstTag
{
    NSString *date = @"#inst \"1985-04-12T23:20:50.52Z\"";
    NSDate *forComparison = [NSDate dateWithTimeIntervalSince1970:482196050.52];
    
    XCTAssertEqualObjects([date ednObject], forComparison, @"");
}

#pragma mark - Writer tests

- (void)testSerializeNumerals {
    XCTAssertEqualObjects([@(1) ednString], @"1", @"");
    XCTAssertEqualObjects([[BMOEDNRatio ratioWithNumerator:22 denominator:7] ednString], @"22/7", @"");
    // TODO: test decimals, floats, etc. (esp for precision)
}

- (void)testSerializeString {
    XCTAssertEqualObjects([@"hello, world!" ednData], [@"\"hello, world!\"" dataUsingEncoding:NSUTF8StringEncoding], @"");
    XCTAssertEqualObjects([@"\\\"" ednString], @"\"\\\\\\\"\"", @"Backslash city.");
}

- (void)testSerializeVector {
    XCTAssertEqualObjects([(@[@1, @2, @"three"]) ednString], @"[ 1 2 \"three\" ]", @"");
    // TODO: whitespace options?
}

- (void)testSerializeSet {
    // Since sets come out unordered, simplest way to test is to
    // parse back in and see if it matches.
    id set = [NSSet setWithArray:(@[@1, @2, @3])];
    XCTAssertEqualObjects([[set ednString] ednObject], set, @"");
}

- (void)testSerializeSymbol {
    id foo = @"foo//";
    XCTAssertEqualObjects([[BMOEDNSymbol symbolWithNamespace:@"foo" name:@"/"] ednString], foo, @"");
    id bar = @":my/bar";
    XCTAssertEqualObjects([[bar ednObject] ednString], bar, @"");
}

- (void)testSerializeTaggedElements {
    // uuid
    NSUUID *uuid = [NSUUID UUID];
    XCTAssertEqualObjects(([uuid ednString]), ([NSString stringWithFormat:@"#uuid \"%@\"",uuid.UUIDString]), @"");
    
    // date
    NSString *date = @"#inst \"1985-04-12T23:20:50.52Z\"";
    NSDate *forComparison = [NSDate dateWithTimeIntervalSince1970:482196050.52];
    XCTAssertEqualObjects(([forComparison ednString]), date, @"");
    
    // arbitrary
    BMOEDNTaggedElement *taggedElement = [BMOEDNTaggedElement elementWithTag:[BMOEDNSymbol symbolWithNamespace:@"my" name:@"foo"] element:@"bar-baz"];
    NSString *taggedElementString = @"#my/foo \"bar-baz\"";
    XCTAssertEqualObjects([taggedElement ednString], taggedElementString, @"");
}

- (void)testSerializeMap {
    id map = @{[BMOEDNKeyword keywordWithNamespace:@"my" name:@"one"]:@1,
               [BMOEDNKeyword keywordWithNamespace:@"your" name:@"two"]:@2,
               @3:[BMOEDNSymbol symbolWithNamespace:@"surprise" name:@"three"]};
    XCTAssertEqualObjects([[map ednString] ednObject], map, @"Ordering is not guaranteed, so we round-trip it up.");
}

- (void)testListFastEnumeration {
    BMOEDNList *list = (BMOEDNList *)[@"(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20)" ednObject];
    NSUInteger i = 1;
    for (NSNumber *num in list) {
        XCTAssertEqual(i++, [num unsignedIntegerValue], @"");
    }
}

- (void)testSerializeList {
    NSString *listString = @"( 1 2 3 4 my/symbol 6 7 8 9 #{ 10 :a :b see } 11 \"twelve\" 13 14 15 16 17 18 19 20 )";
    BMOEDNList *list = (BMOEDNList *)[listString ednObject];
    XCTAssertEqualObjects([[list ednString] ednObject], list, @"");
}

- (void)testListOperations {
    BMOEDNList *list = [@"(4 3 2 1)" ednObject];
    BMOEDNList *pushed = [@"(5 4 3 2 1)" ednObject];
    BMOEDNList *popped = [@"(3 2 1)" ednObject];
    XCTAssertEqualObjects([list listByPushing:@5], pushed, @"");
    XCTAssertEqualObjects([list listByPopping], popped, @"");
}

- (void)testSerializeNull {
    XCTAssertEqualObjects([[NSNull null] ednString], @"nil", @"");
    id nullList = [@"( nil nil 1 nil )" ednObject];
    XCTAssertEqualObjects(nullList, [[nullList ednString] ednObject], @"");
}

- (void)testSerializeBooleans {
    XCTAssertEqualObjects([(@[(__bridge NSNumber *)kCFBooleanTrue, (__bridge NSNumber *)kCFBooleanFalse]) ednString], @"[ true false ]", @"");
    
}

// roughly 128 bits at this point.
- (void)testGiganticInteger {
    NSString *ullMax = [NSString stringWithFormat:@"%llu",ULLONG_MAX];
    NSString *number = [[ullMax stringByAppendingString:ullMax] substringToIndex:ullMax.length*2-1];
    NSLog(@"ULLONG_MAX * (2^64 + 1) / 10: %@",number);
    XCTAssertEqualObjects([[[number stringByAppendingString:@"N"] ednObject] ednString],number, @"");
}

- (void)testParseMetadata {
    NSString *mapWithMeta = @"^{ :my/metaKey true } { :key1 1 :key2 ^{ :my/metaKey false } 2 :listKey ( 1 2 ^{ :my/foo bar } 3 ) }";
    
    id obj = (@{ [@":key1" ednObject]: @1, [@":key2" ednObject]: @2, [@":listKey" ednObject]: [@"( 1 2 3 )" ednObject]});
    
    id parsedObj = [mapWithMeta ednObject];
    XCTAssertEqualObjects(parsedObj, obj, @"Meta should not be factored into equality checks.");
    
    XCTAssertEqualObjects([@"{ :my/metaKey true }" ednObject], [parsedObj ednMetadata], @"Find the metadata.");
    
    XCTAssertNil([obj ednMetadata], @"Unparsed object has no meta.");
    
    XCTAssertNil([@"^{ :foo \"firstMeta\" } ^{ :bar \"secondMeta\"} 1" ednObject], @"Double-meta is invalid.");
    
}


- (void)testSetMetadata {
    // ensure metadata on metadata throws an exception
    id obj2 = [NSDictionary dictionaryWithObjectsAndKeys:@1, @"one", nil];
    id meta = [NSDictionary dictionaryWithObjectsAndKeys:@2, @"two", nil];
    id metaMeta = [NSDictionary dictionaryWithObjectsAndKeys:@3, @"three", nil];
    XCTAssertNoThrow([obj2 setEdnMetadata:meta], @"");
    XCTAssertEqual(([obj2 ednMetadata]), meta, @"");
    XCTAssertThrows([metaMeta setEdnMetadata:obj2], @"");
    
    id literalMeta = [NSDictionary new];
    // null, true, false must not have metadata
    XCTAssertThrows([[NSNull null] setEdnMetadata:literalMeta], @"");
    XCTAssertThrows([(__bridge NSNumber *)kCFBooleanTrue setEdnMetadata:literalMeta], @"");
    XCTAssertThrows([(__bridge NSNumber *)kCFBooleanFalse setEdnMetadata:literalMeta], @"");
    //STAssertThrows([@"foo" setEdnMetadata:literalMeta], @"String literal may be constant and should not accept metadata (lest undefined behavior emerge)."); // yet unable to determine without hackzzz
}

- (void)testWriteMetadata {
    // write meta
    id meta = [NSDictionary new];
    NSArray *array = [NSArray arrayWithObjects:@1, @2, @3, nil];
    [array setEdnMetadata:meta];
    XCTAssertEqualObjects([array ednString], @"[ 1 2 3 ]", @"Empty metadata should not be serialized out.");
    [array setEdnMetadata:@{ @1: @"one" }];
    XCTAssertEqualObjects([array ednString], @"^{ 1 \"one\" } [ 1 2 3 ]", @"");
    id list = [@"( one two three )" ednObject];
    [list setEdnMetadata:@{ [BMOEDNKeyword keywordWithNamespace:nil name:@"type"] : [BMOEDNSymbol symbolWithNamespace:nil name:@"list"] }];
    array = [array arrayByAddingObject:list];
    XCTAssertEqualObjects([array ednString], @"[ 1 2 3 ^{ :type list } ( one two three ) ]", @"Array metadata is not preserved (array with added object is a new array).");
}

- (void)testReadMultipleRootObjects {
    NSString * obj1String = @"( 1 2 3 )";
    NSString * obj2String = @"[ 1 2 3 ]";
    NSString * objsString = [NSString stringWithFormat:@"%@ %@",obj1String, obj2String];
    id objs = [BMOEDNSerialization ednObjectWithData:[objsString dataUsingEncoding:NSUTF8StringEncoding] options:BMOEDNReadingMultipleObjects error:NULL];
    
    id expectedObjs = (@[[obj1String ednObject],[obj2String ednObject]]);
    
    XCTAssertTrue([objs conformsToProtocol:@protocol(NSFastEnumeration)], @"Multi-objects flag should return an enumerable, regardless of number of elements.");
    
    NSUInteger current = 0;
    for (id obj in objs) {
        XCTAssertEqualObjects(obj, expectedObjs[current++], @"");
    }
    
    XCTAssertEqualObjects([objsString ednObject], expectedObjs[0], @"Without multi-object flag asserted, should return first object, if valid.");
    
    
}

- (void)testWriteMultipleRootObjects {
    id objs = (@[@1, @2, @{ @"three" : @3 }]);
    XCTAssertEqualObjects([[[BMOEDNRoot alloc] initWithArray:objs] ednString], @"1\n2\n{ \"three\" 3 }\n", @"");
    
    id clojureCode = @"( + 1 2 )\n( map [ x y ] ( 3 4 5 ) )\n[ a root vector is \"weird\" ]\n";
    id clojureData = [[clojureCode dataUsingEncoding:NSUTF8StringEncoding] ednObject];
    XCTAssertEqualObjects([clojureData ednString], clojureCode, @"");
    
    XCTAssertNil([(@[[[BMOEDNRoot alloc] initWithArray:@[@1, @2]], @3]) ednString],@"Root object not at root of graph must be treated as invalid data.");
}
/*
 - (void)testRootObjectEquality {
 id clojureCode = @"( + 1 2 )\n( map [ x y ] ( 3 4 5 ) )\n[ a root vector is \"weird\" ]\n";
 id clojureData = [clojureCode dataUsingEncoding:NSUTF8StringEncoding];
 id rootOne = [clojureData ednObject]; //1
 id rootTwo = [clojureData ednObject]; //1.4142
 
 STAssertFalse(rootOne == rootTwo, @"");
 STAssertEqualObjects(rootOne, rootTwo, @"Two documents derived from the same edn should be equal.");
 STAssertEquals([rootOne hash], [rootTwo hash], @"Equal objects' hashes should be equal.");
 }
 */

#pragma mark - Stream reading

- (void)testReadFromStream {
    id clojureCode = @"( + 1 2 )\n( map [ x y ] ( 3 4 5 ) )\n[ a root vector is \"weird\" ]\n";
    id clojureData = [clojureCode dataUsingEncoding:NSUTF8StringEncoding];
    id clojureStream = [[NSInputStream alloc] initWithData:clojureData];
    id ednObjectStream = [clojureStream ednObject];
    NSMutableArray * collector = [NSMutableArray new];
    for (id obj in [clojureData ednObject]) {
        if (obj == nil) XCTFail(@"Object should not be nil.");
        [collector addObject:obj];
    }
    NSEnumerator *enumerator = [collector objectEnumerator];
    for (id obj in ednObjectStream) {
        XCTAssertEqualObjects(obj, [enumerator nextObject], @"");
    }
    
}

#pragma mark - BMOEDNRoot

- (void)testNSEnumeratorBackedRootRealization {
    id objs = [@"[ 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 ]" ednObject];
    id root = [[BMOEDNRoot alloc] initWithEnumerator:[objs objectEnumerator]];
    NSUInteger currentNumber = 1;
    for (NSNumber *num in root) {
        XCTAssertEqual([num unsignedIntegerValue],currentNumber++, @"");
    }
    
    // reset, attempt to re-enumerate
    currentNumber = 1;
    for (NSNumber *num in root) {
        XCTAssertEqual([num unsignedIntegerValue],currentNumber++, @"");
    }
    XCTAssertEqual(currentNumber, (NSUInteger)25, @"Root should have enumerated through all 24 objects.");
}

- (void)testRootIndexing {
    id objs = [@"[ 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 ]" ednObject];
    id root = [[BMOEDNRoot alloc] initWithEnumerator:[objs objectEnumerator]];
    // sequentially
    for (NSUInteger i = 0; i < 10; i++) {
        XCTAssertEqual(i+1, [root[i] unsignedIntegerValue], @"");
    }
    
    // with realization from the end
    for (NSUInteger i = 20; i >= 10; i--) {
        XCTAssertEqual(i+1, [root[i] unsignedIntegerValue], @"");
    }
    
    // out of range exception
    id blah;
    XCTAssertThrows((blah = root[[objs count]]), @"");
    
    // same tests again, with an NSArray-backed root
    root = [[BMOEDNRoot alloc] initWithArray:objs];
    // sequentially
    for (NSUInteger i = 0; i < 10; i++) {
        XCTAssertEqual(i+1, [root[i] unsignedIntegerValue], @"");
    }
    
    // with realization from the end
    for (NSUInteger i = 20; i >= 10; i--) {
        XCTAssertEqual(i+1, [root[i] unsignedIntegerValue], @"");
    }
    
    // out of range exception
    XCTAssertThrows((blah = root[[objs count]]), @"");
}

///* TODO: fix
- (void)testRootEnumerator {
    id objs = [@"[ 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 ]" ednObject];
    id root = [[BMOEDNRoot alloc] initWithEnumerator:[objs objectEnumerator]];
    NSMutableSet *collector1 = [NSMutableSet new];
    NSMutableSet *collector2 = [NSMutableSet new];
    NSEnumerator *enumerator = [root objectEnumerator];
    dispatch_queue_t queue = dispatch_queue_create("RootEnumeratorTestQueue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_group_t dispatchGroup = dispatch_group_create();
    for (int i = 0; i < [objs count]/2; i++) {
        dispatch_group_async(dispatchGroup, queue, ^{
            id obj = [enumerator nextObject];
            if (obj) {
                @synchronized(collector1) {
                    [collector1 addObject:obj];
                }
            }
        });
        dispatch_group_async(dispatchGroup, queue, ^{
            id obj = [enumerator nextObject];
            if (obj) {
                @synchronized(collector2) {
                    [collector2 addObject:obj];
                }
            }
        });
    }
    XCTAssertEqual(0L,dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER),@"Error during group wait?");
    XCTAssertEqual([objs count], [collector1 count] + [collector2 count], @"Collectors should have split the objects.");
    XCTAssertEqualObjects([NSSet setWithArray:objs], [collector1 setByAddingObjectsFromSet:collector2], @"Collectors should contain the same set as the array did.");
}

#pragma mark - Lazy enumerator

- (void)testLazyEnumerator {
    NSEnumerator * enumerator = [[BMOLazyEnumerator alloc] initWithBlock:^id(NSUInteger idx, id last) {
        return idx < 1000 ? @(idx) : nil;
    }];
    for (int i = 0; i < 1000; i++) {
        XCTAssertEqualObjects([NSNumber numberWithInt:i], [enumerator nextObject], @"");
    }
    XCTAssertNil([enumerator nextObject], @"");
}

- (void)testLazyErrors {
    NSError *err = nil;
    NSData *data = [@"[ 1 2 :::::}}}}}" dataUsingEncoding:NSUTF8StringEncoding];
    [BMOEDNSerialization ednObjectWithData:data options:0 error:&err];
    XCTAssertTrue(err!=nil, @"Should produce an error.");
    err = nil;
    id root = [BMOEDNSerialization ednObjectWithData:data options:BMOEDNReadingLazyParsing|BMOEDNReadingMultipleObjects error:&err];
    XCTAssertNil(err, @"Error is not immediate w/ lazy parsing.");
    NSUInteger count = 0;
    for (id obj in root) {
        XCTAssertTrue([obj isMemberOfClass:[NSError class]], @"Invalid data should lazily return an error.");
        XCTAssertTrue(count++ <= 1, @"Should only return one error.");
        
        if (count > 10) break;
    }
}

- (void)testWritingToStream {
    NSMutableString *testString = [[NSMutableString alloc] init];
    NSOutputStream *stream = [NSOutputStream outputStreamToMemory];
    NSError *err = nil;
    NSMutableArray *collector = [NSMutableArray array];
    for (int i = 0; i < 10; i++) {
        id obj = @{[NSString stringWithFormat:@"%d",i]:@(i)};
        [BMOEDNSerialization writeEdnObject:obj toStream:stream error:&err];
        [testString appendFormat:@"{ \"%1$d\" %1$d }\n",i];
        [collector addObject:obj];
    }
    XCTAssertNil(err, @"");
    NSData *data = [stream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
    NSString *stringified = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    BMOEDNRoot *root = [[BMOEDNRoot alloc] initWithArray:collector];
    XCTAssertEqualObjects(stringified, [root ednString], @"Sanity check for comparison.");
    XCTAssertEqualObjects(stringified, testString, @"Multi-object stream test.");
}


#pragma mark - Characters

- (void)testParseCharacters {
    NSString *charVector = @"[ \\newline \\n \\! \\* \"fooey\" \\& \\space \\tab \\return]";
    id edn = [charVector ednObject];
    XCTAssertTrue(edn != nil, @"Should parse into something.");
    XCTAssertEqualObjects([BMOEDNCharacter characterWithUnichar:'\n'], edn[0], @"");
    XCTAssertEqualObjects([BMOEDNCharacter characterWithUnichar:'n'], edn[1], @"");
    XCTAssertEqualObjects([BMOEDNCharacter characterWithUnichar:'!'], edn[2], @"");
    XCTAssertEqualObjects([BMOEDNCharacter characterWithUnichar:'*'], edn[3], @"");
    XCTAssertEqualObjects(@"fooey", edn[4], @"");
    XCTAssertEqualObjects([BMOEDNCharacter characterWithUnichar:'&'], edn[5], @"");
    XCTAssertEqualObjects([BMOEDNCharacter characterWithUnichar:' '], edn[6], @"");
    XCTAssertEqualObjects([BMOEDNCharacter characterWithUnichar:'\t'], edn[7], @"");
    XCTAssertEqualObjects([BMOEDNCharacter characterWithUnichar:'\r'], edn[8], @"");
    
    XCTAssertNil([@"\\ " ednObject], @"");
}

- (void)testWriteCharacters {
    NSArray *charVector = @[[BMOEDNCharacter characterWithUnichar:'\n'],
                            [BMOEDNCharacter characterWithUnichar:'n'],
                            [BMOEDNCharacter characterWithUnichar:'!'],
                            [BMOEDNCharacter characterWithUnichar:'*'],
                            @"fooey",
                            [BMOEDNCharacter characterWithUnichar:'&'],
                            [BMOEDNCharacter characterWithUnichar:' '],
                            [BMOEDNCharacter characterWithUnichar:'\t'],
                            [BMOEDNCharacter characterWithUnichar:'\r']];
    NSString *edn = [charVector ednString];
    XCTAssertEqualObjects(edn, @"[ \\newline \\n \\! \\* \"fooey\" \\& \\space \\tab \\return ]", @"");
}

#pragma mark - UTF-8 (beyond ASCII)

- (void)testUTFStreamRead {
    NSString *utfString = @"πƒ©wheeyaulrd¥¨¬∂¥¨®å…œ©¬";
    NSString *ednString = [NSString stringWithFormat:@"\"%@\"",utfString];
    NSInputStream *stream = [NSInputStream inputStreamWithData:[ednString dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSError *err = nil;
    id read = [BMOEDNSerialization ednObjectWithStream:stream options:0 error:&err];
    XCTAssertNil(err, @"Error should be nil.");
    
    XCTAssertEqualObjects(utfString, read, @"String should be read back out as it went in.");
    
    // edn UTF-8 character
    NSInputStream *charStream = [NSInputStream inputStreamWithData:[@"[ \\π ]" dataUsingEncoding:NSUTF8StringEncoding]];
    
    read = [BMOEDNSerialization ednObjectWithStream:charStream options:0 error:&err];
    XCTAssertNil(err, @"Error should be nil.");
    
    XCTAssertEqualObjects((@[[BMOEDNCharacter characterWithUnichar:0x03C0]]), read, @"Character array should be read back out as it went in.");
    
}

- (void)testUTFDataRead {
    NSString *utfString = @"πƒ©wheeyaulrd¥¨¬∂¥¨®å…œ©¬";
    NSString *ednString = [NSString stringWithFormat:@"\"%@\"",utfString];
    NSData *data = [ednString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSError *err = nil;
    id read = [BMOEDNSerialization ednObjectWithData:data options:0 error:&err];
    XCTAssertNil(err, @"Error should be nil.");
    
    XCTAssertEqualObjects(utfString, read, @"String should be read back out as it went in.");
    
    // edn UTF-8 character
    NSData *charData = [@"[ \\π ]" dataUsingEncoding:NSUTF8StringEncoding];
    
    read = [BMOEDNSerialization ednObjectWithData:charData options:0 error:&err];
    XCTAssertNil(err, @"Error should be nil.");
    
    XCTAssertEqualObjects((@[[BMOEDNCharacter characterWithUnichar:0x03C0]]), read, @"Character array should be read back out as it went in.");
}

- (void)testUTFWrite {
    NSString *utfString = @"πƒ©wheeyaulrd¥¨¬∂¥¨®å…œ©¬";
    NSString *ednString = [NSString stringWithFormat:@"\"%@\"",utfString];
    XCTAssertEqualObjects(ednString, [[NSString alloc] initWithData:[utfString ednData] encoding:NSUTF8StringEncoding], @"String should be read back out as it went in.");
    
    // edn UTF-8 character
    ednString = @"[ \\π ]";
    
    XCTAssertEqualObjects([ednString dataUsingEncoding:NSUTF8StringEncoding], [(@[[BMOEDNCharacter characterWithUnichar:0x03C0]]) ednData], @"Character array should be read back out as it went in.");
    
}

- (void)testUTF8Symbol {
    NSString *anonymous = @"(ƒ [x y] (ƒ (+ x y)))";
    // TODO: round out
    XCTAssertTrue([anonymous ednObject] != nil, @"");
}

- (void)testWriteNSData {
    NSData *anonData = [[NSData alloc] initWithBase64EncodedString:@"KMaSIFt4IHldICjGkiAoKyB4IHkpKSk=" options:0];
    NSString *expected = [NSString stringWithFormat:@"#edn-objc/NSData \"%@\"", [anonData base64EncodedStringWithOptions:0]];
    XCTAssertEqualObjects([anonData ednString], expected, @"");
}

- (void)testReadNSData {
    NSData *anonData = [[NSData alloc] initWithBase64EncodedString:@"KMaSIFt4IHldICjGkiAoKyB4IHkpKSk=" options:0];
    id roundTripped = [[anonData ednString] ednObject];
    XCTAssertEqualObjects(anonData, roundTripped, @"");
}

- (void)testWriteArbitraryNSCoding {
    NSCodingFoo *foo = [NSCodingFoo new];
    foo.a = 42;
    foo.b = @"life, the universe, everything";
    
    NSCodingBar *bar = [NSCodingBar new];
    bar.array = @[@3, @2, @1];
    
    foo.bar = bar;
    
    NSString *expected = @"#edn-objc/NSCodingFoo { :a 42 :b \"life, the universe, everything\" :bar #edn-objc/NSCodingBar { :array [ 3 2 1 ] :dict nil } }";
    XCTAssertEqualObjects([foo ednString], expected, @"");
}

- (void)testReadArbitraryNSCoding {
    NSCodingFoo *foo = [NSCodingFoo new];
    foo.a = 42;
    foo.b = @"life, the universe, everything";
    
    NSCodingBar *bar = [NSCodingBar new];
    bar.array = @[@3, @2, @1];
    
    foo.bar = bar;
    
    id roundTripped = [[foo ednString] ednObject];
    XCTAssertEqualObjects(foo, roundTripped, @"");
}


- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
